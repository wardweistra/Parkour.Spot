const {
  extractUserIdOrUsername,
  inviteToSpotList,
  respondToSpotListInvite,
  updateSpotListMemberRole,
  removeSpotListMember,
} = require("../lib/spot-list-sharing");

class FakeHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function createDb({lists = {}, invites = {}, users = {}} = {}) {
  const store = {
    spotLists: {...lists},
    spotListInvites: {...invites},
    users: {...users},
  };

  function docRef(collection, id) {
    return {
      id,
      get: async () => {
        const data = store[collection][id];
        return {
          exists: data != null,
          id,
          data: () => data,
        };
      },
      set: async (data) => {
        store[collection][id] = {...data};
      },
      update: async (data) => {
        store[collection][id] = {...store[collection][id], ...applyUpdates(data)};
      },
    };
  }

  function applyUpdates(data) {
    const out = {};
    for (const [key, value] of Object.entries(data)) {
      if (value && value._op === "arrayUnion") {
        const current = Array.isArray(store.spotLists[
            Object.keys(store.spotLists).find(() => true)
        ]?.[key]) ? null : null;
        void current;
        // Handled in transaction mocks below for list membership.
        out[key] = value;
      } else if (value && value._op === "arrayRemove") {
        out[key] = value;
      } else if (value && value._ts) {
        out[key] = new Date();
      } else {
        out[key] = value;
      }
    }
    return out;
  }

  return {
    store,
    collection: (name) => ({
      doc: (id) => {
        if (!id) {
          const autoId = `auto_${Object.keys(store[name] || {}).length + 1}`;
          return docRef(name, autoId);
        }
        return docRef(name, id);
      },
      where: (field, _op, value) => {
        const chain = {
          _filters: [{field, value}],
          where(field2, _op2, value2) {
            chain._filters.push({field: field2, value: value2});
            return chain;
          },
          limit() {
            return chain;
          },
          async get() {
            const docs = Object.entries(store[name] || {})
                .filter(([id, data]) =>
                  chain._filters.every((f) => data[f.field] === f.value),
                )
                .map(([id, data]) => ({
                  id,
                  data: () => data,
                }));
            return {empty: docs.length === 0, docs};
          },
        };
        return chain;
      },
    }),
    runTransaction: async (fn) => {
      const tx = {
        get: async (ref) => ref.get(),
        update: async (ref, data) => {
          const col = ref._collection || inferCollection(ref);
          const id = ref.id;
          const current = {...(store[col][id] || {})};
          for (const [key, value] of Object.entries(data)) {
            if (value && value._op === "arrayUnion") {
              const arr = Array.isArray(current[key]) ? [...current[key]] : [];
              if (!arr.includes(value.uid)) arr.push(value.uid);
              current[key] = arr;
            } else if (value && value._op === "arrayRemove") {
              const arr = Array.isArray(current[key]) ? [...current[key]] : [];
              current[key] = arr.filter((x) => x !== value.uid);
            } else if (value && value._ts) {
              current[key] = new Date();
            } else {
              current[key] = value;
            }
          }
          store[col][id] = current;
        },
      };
      // Patch refs used in transaction to know their collection.
      const origCollection = this?.collection;
      void origCollection;
      return fn(tx);
    },
  };
}

function inferCollection(ref) {
  // Our fake refs do not carry collection; tests patch via wrapper below.
  return ref._col;
}

const FieldValue = {
  serverTimestamp: () => ({_ts: true}),
  arrayUnion: (uid) => ({_op: "arrayUnion", uid}),
  arrayRemove: (uid) => ({_op: "arrayRemove", uid}),
};

describe("extractUserIdOrUsername", () => {
  it("parks profile URLs and raw usernames", () => {
    expect(extractUserIdOrUsername("trainer")).toBe("trainer");
    expect(extractUserIdOrUsername("https://parkour.spot/user/trainer"))
        .toBe("trainer");
    expect(extractUserIdOrUsername("parkour.spot/user/abc123"))
        .toBe("abc123");
  });
});

describe("inviteToSpotList", () => {
  it("creates a pending invite and notifies the invitee", async () => {
    const listId = "list1";
    const owner = "owneruidowneruidowneruidown"; // 28
    const invitee = "inviteeuidinviteeuidinviteeu"; // 28
    const db = createDb({
      lists: {
        [listId]: {name: "Jam map", createdBy: owner, editorIds: [], viewerIds: []},
      },
      invites: {},
      users: {
        [owner]: {displayName: "Owner"},
        [invitee]: {displayName: "Friend", username: "friend"},
      },
    });

    // Enhance collection().doc to stamp _col for transactions / updates.
    const rawCollection = db.collection.bind(db);
    db.collection = (name) => {
      const col = rawCollection(name);
      const rawDoc = col.doc.bind(col);
      col.doc = (id) => {
        const ref = rawDoc(id);
        ref._col = name;
        return ref;
      };
      return col;
    };

    const delivered = [];
    const result = await inviteToSpotList({
      db,
      FieldValue,
      HttpsError: FakeHttpsError,
      deliverNotifications: async (opts) => {
        delivered.push(opts);
        return {notified: 1};
      },
      authUid: owner,
      listId,
      inviteeRaw: invitee,
      role: "edit",
    });

    expect(result.success).toBe(true);
    expect(result.status).toBe("pending");
    expect(delivered).toHaveLength(1);
    expect(delivered[0].payload.notificationKind).toBe("spot_list_invite");
    expect(delivered[0].userIds).toEqual([invitee]);
  });

  it("rejects duplicate active invites", async () => {
    const listId = "list1";
    const owner = "owneruidowneruidowneruidown";
    const invitee = "inviteeuidinviteeuidinviteeu";
    const db = createDb({
      lists: {
        [listId]: {name: "Jam map", createdBy: owner},
      },
      invites: {
        inv1: {
          listId,
          inviteeUid: invitee,
          status: "pending",
          role: "view",
        },
      },
      users: {
        [invitee]: {displayName: "Friend"},
      },
    });
    const rawCollection = db.collection.bind(db);
    db.collection = (name) => {
      const col = rawCollection(name);
      const rawDoc = col.doc.bind(col);
      col.doc = (id) => {
        const ref = rawDoc(id);
        ref._col = name;
        return ref;
      };
      return col;
    };

    await expect(inviteToSpotList({
      db,
      FieldValue,
      HttpsError: FakeHttpsError,
      deliverNotifications: async () => ({notified: 0}),
      authUid: owner,
      listId,
      inviteeRaw: invitee,
      role: "view",
    })).rejects.toMatchObject({code: "already-exists"});
  });
});

describe("respondToSpotListInvite", () => {
  it("accepts and grants editor membership", async () => {
    const listId = "list1";
    const owner = "owneruidowneruidowneruidown";
    const invitee = "inviteeuidinviteeuidinviteeu";
    const db = createDb({
      lists: {
        [listId]: {name: "Jam map", createdBy: owner, editorIds: [], viewerIds: []},
      },
      invites: {
        inv1: {
          listId,
          listName: "Jam map",
          inviterUid: owner,
          inviteeUid: invitee,
          role: "edit",
          status: "pending",
        },
      },
      users: {
        [invitee]: {displayName: "Friend"},
      },
    });
    const rawCollection = db.collection.bind(db);
    db.collection = (name) => {
      const col = rawCollection(name);
      const rawDoc = col.doc.bind(col);
      col.doc = (id) => {
        const ref = rawDoc(id);
        ref._col = name;
        return ref;
      };
      return col;
    };

    const result = await respondToSpotListInvite({
      db,
      FieldValue,
      HttpsError: FakeHttpsError,
      deliverNotifications: async () => ({notified: 1}),
      authUid: invitee,
      inviteId: "inv1",
      accept: true,
    });

    expect(result.status).toBe("accepted");
    expect(db.store.spotListInvites.inv1.status).toBe("accepted");
    expect(db.store.spotLists[listId].editorIds).toContain(invitee);
  });

  it("declines without granting membership", async () => {
    const listId = "list1";
    const owner = "owneruidowneruidowneruidown";
    const invitee = "inviteeuidinviteeuidinviteeu";
    const db = createDb({
      lists: {
        [listId]: {name: "Jam map", createdBy: owner, editorIds: [], viewerIds: []},
      },
      invites: {
        inv1: {
          listId,
          listName: "Jam map",
          inviterUid: owner,
          inviteeUid: invitee,
          role: "view",
          status: "pending",
        },
      },
    });
    const rawCollection = db.collection.bind(db);
    db.collection = (name) => {
      const col = rawCollection(name);
      const rawDoc = col.doc.bind(col);
      col.doc = (id) => {
        const ref = rawDoc(id);
        ref._col = name;
        return ref;
      };
      return col;
    };

    const result = await respondToSpotListInvite({
      db,
      FieldValue,
      HttpsError: FakeHttpsError,
      deliverNotifications: async () => ({notified: 0}),
      authUid: invitee,
      inviteId: "inv1",
      accept: false,
    });

    expect(result.status).toBe("declined");
    expect(db.store.spotLists[listId].editorIds || []).not.toContain(invitee);
    expect(db.store.spotLists[listId].viewerIds || []).not.toContain(invitee);
  });
});

describe("updateSpotListMemberRole and removeSpotListMember", () => {
  it("moves an accepted member from view to edit", async () => {
    const listId = "list1";
    const owner = "owneruidowneruidowneruidown";
    const invitee = "inviteeuidinviteeuidinviteeu";
    const db = createDb({
      lists: {
        [listId]: {
          name: "Jam map",
          createdBy: owner,
          editorIds: [],
          viewerIds: [invitee],
        },
      },
      invites: {
        inv1: {
          listId,
          inviteeUid: invitee,
          role: "view",
          status: "accepted",
        },
      },
    });
    const rawCollection = db.collection.bind(db);
    db.collection = (name) => {
      const col = rawCollection(name);
      const rawDoc = col.doc.bind(col);
      col.doc = (id) => {
        const ref = rawDoc(id);
        ref._col = name;
        return ref;
      };
      return col;
    };

    await updateSpotListMemberRole({
      db,
      FieldValue,
      HttpsError: FakeHttpsError,
      authUid: owner,
      inviteId: "inv1",
      role: "edit",
    });

    expect(db.store.spotListInvites.inv1.role).toBe("edit");
    expect(db.store.spotLists[listId].editorIds).toContain(invitee);
    expect(db.store.spotLists[listId].viewerIds).not.toContain(invitee);
  });

  it("lets invitee leave an accepted share", async () => {
    const listId = "list1";
    const owner = "owneruidowneruidowneruidown";
    const invitee = "inviteeuidinviteeuidinviteeu";
    const db = createDb({
      lists: {
        [listId]: {
          name: "Jam map",
          createdBy: owner,
          editorIds: [invitee],
          viewerIds: [],
        },
      },
      invites: {
        inv1: {
          listId,
          inviteeUid: invitee,
          role: "edit",
          status: "accepted",
        },
      },
    });
    const rawCollection = db.collection.bind(db);
    db.collection = (name) => {
      const col = rawCollection(name);
      const rawDoc = col.doc.bind(col);
      col.doc = (id) => {
        const ref = rawDoc(id);
        ref._col = name;
        return ref;
      };
      return col;
    };

    const result = await removeSpotListMember({
      db,
      FieldValue,
      HttpsError: FakeHttpsError,
      authUid: invitee,
      inviteId: "inv1",
    });

    expect(result.status).toBe("left");
    expect(db.store.spotLists[listId].editorIds).not.toContain(invitee);
  });
});
