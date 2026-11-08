/**
 * Spot list sharing: invite, accept/decline, role changes, remove/leave.
 * Membership arrays on spotLists are written only via Admin SDK here.
 */

const ACTIVE_STATUSES = new Set(["pending", "accepted"]);
const ROLES = new Set(["edit", "view"]);

/**
 * @param {string} raw
 * @return {string}
 */
function extractUserIdOrUsername(raw) {
  const trimmed = typeof raw === "string" ? raw.trim() : "";
  if (!trimmed) {
    return "";
  }
  try {
    const withScheme = /^https?:\/\//i.test(trimmed) ?
      trimmed :
      `https://${trimmed}`;
    const url = new URL(withScheme);
    const host = url.hostname.toLowerCase();
    if (host === "parkour.spot" || host === "www.parkour.spot" ||
        host.endsWith(".parkour.spot")) {
      const match = url.pathname.match(/\/user\/([^/]+)/i);
      if (match && match[1]) {
        return decodeURIComponent(match[1]).trim();
      }
    }
  } catch (_) {
    // Not a URL — treat as username/uid.
  }
  const pathMatch = trimmed.match(/(?:^|\/)user\/([^/?#]+)/i);
  if (pathMatch && pathMatch[1]) {
    return decodeURIComponent(pathMatch[1]).trim();
  }
  return trimmed;
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} raw
 * @param {object} HttpsError
 * @return {Promise<string>}
 */
async function resolveInviteeUid(db, raw, HttpsError) {
  const idOrUsername = extractUserIdOrUsername(raw);
  if (!idOrUsername) {
    throw new HttpsError("invalid-argument", "invitee is required");
  }

  if (idOrUsername.length === 28) {
    const byId = await db.collection("users").doc(idOrUsername).get();
    if (byId.exists) {
      return byId.id;
    }
  }

  const username = idOrUsername.toLowerCase();
  const byUsername = await db.collection("users")
      .where("username", "==", username)
      .limit(1)
      .get();
  if (!byUsername.empty) {
    return byUsername.docs[0].id;
  }

  // Fallback: try doc id even when length !== 28.
  const fallback = await db.collection("users").doc(idOrUsername).get();
  if (fallback.exists) {
    return fallback.id;
  }

  throw new HttpsError("not-found", "User not found");
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} uid
 * @return {Promise<string>}
 */
async function loadActorName(db, uid) {
  const snap = await db.collection("users").doc(uid).get();
  if (!snap.exists) {
    return "Someone";
  }
  const data = snap.data() || {};
  if (typeof data.displayName === "string" && data.displayName.trim()) {
    return data.displayName.trim();
  }
  if (typeof data.username === "string" && data.username.trim()) {
    return data.username.trim();
  }
  return "Someone";
}

/**
 * @param {FirebaseFirestore.Firestore} db
 * @param {string} listId
 * @param {string} inviteeUid
 * @return {Promise<FirebaseFirestore.QueryDocumentSnapshot|null>}
 */
async function findActiveInvite(db, listId, inviteeUid) {
  const snap = await db.collection("spotListInvites")
      .where("listId", "==", listId)
      .where("inviteeUid", "==", inviteeUid)
      .get();
  for (const doc of snap.docs) {
    const status = doc.data().status;
    if (ACTIVE_STATUSES.has(status)) {
      return doc;
    }
  }
  return null;
}

/**
 * @param {object} listData
 * @param {string} uid
 * @param {string} role
 * @param {object} FieldValue
 * @return {object}
 */
function membershipUpdatesForAccept(listData, uid, role, FieldValue) {
  const editorIds = Array.isArray(listData.editorIds) ? listData.editorIds : [];
  const viewerIds = Array.isArray(listData.viewerIds) ? listData.viewerIds : [];
  const updates = {
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (role === "edit") {
    updates.editorIds = FieldValue.arrayUnion(uid);
    if (viewerIds.includes(uid)) {
      updates.viewerIds = FieldValue.arrayRemove(uid);
    }
  } else {
    updates.viewerIds = FieldValue.arrayUnion(uid);
    if (editorIds.includes(uid)) {
      updates.editorIds = FieldValue.arrayRemove(uid);
    }
  }
  return updates;
}

/**
 * @param {object} options
 * @return {Promise<object>}
 */
async function inviteToSpotList({
  db,
  FieldValue,
  HttpsError,
  deliverNotifications,
  authUid,
  listId,
  inviteeRaw,
  role,
}) {
  if (!authUid) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }
  if (typeof listId !== "string" || !listId.trim()) {
    throw new HttpsError("invalid-argument", "listId is required");
  }
  if (!ROLES.has(role)) {
    throw new HttpsError("invalid-argument", "role must be edit or view");
  }

  const listRef = db.collection("spotLists").doc(listId.trim());
  const listSnap = await listRef.get();
  if (!listSnap.exists) {
    throw new HttpsError("not-found", "Spot list not found");
  }
  const listData = listSnap.data() || {};
  if (listData.createdBy !== authUid) {
    throw new HttpsError(
        "permission-denied",
        "Only the list owner can invite others",
    );
  }

  const inviteeUid = await resolveInviteeUid(db, inviteeRaw, HttpsError);
  if (inviteeUid === authUid) {
    throw new HttpsError("invalid-argument", "You cannot invite yourself");
  }

  const existing = await findActiveInvite(db, listId.trim(), inviteeUid);
  if (existing) {
    throw new HttpsError(
        "already-exists",
        "This user already has a pending or accepted invite",
    );
  }

  const listName = typeof listData.name === "string" && listData.name.trim() ?
    listData.name.trim() :
    "Untitled list";
  const inviteRef = db.collection("spotListInvites").doc();
  await inviteRef.set({
    listId: listId.trim(),
    listName,
    inviterUid: authUid,
    inviteeUid,
    role,
    status: "pending",
    createdAt: FieldValue.serverTimestamp(),
    respondedAt: null,
  });

  const actorName = await loadActorName(db, authUid);
  await deliverNotifications({
    db,
    FieldValue,
    userIds: [inviteeUid],
    payload: {
      notificationKind: "spot_list_invite",
      templateArgs: {
        actorName,
        listName,
        inviteId: inviteRef.id,
      },
      deeplinkKind: "list",
      deeplinkId: listId.trim(),
    },
  });

  return {
    success: true,
    inviteId: inviteRef.id,
    inviteeUid,
    role,
    status: "pending",
  };
}

/**
 * @param {object} options
 * @return {Promise<object>}
 */
async function respondToSpotListInvite({
  db,
  FieldValue,
  HttpsError,
  deliverNotifications,
  authUid,
  inviteId,
  accept,
}) {
  if (!authUid) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }
  if (typeof inviteId !== "string" || !inviteId.trim()) {
    throw new HttpsError("invalid-argument", "inviteId is required");
  }
  if (typeof accept !== "boolean") {
    throw new HttpsError("invalid-argument", "accept boolean is required");
  }

  const inviteRef = db.collection("spotListInvites").doc(inviteId.trim());
  const result = await db.runTransaction(async (tx) => {
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) {
      throw new HttpsError("not-found", "Invite not found");
    }
    const invite = inviteSnap.data() || {};
    if (invite.inviteeUid !== authUid) {
      throw new HttpsError(
          "permission-denied",
          "Only the invitee can respond",
      );
    }
    if (invite.status !== "pending") {
      throw new HttpsError(
          "failed-precondition",
          "Invite is no longer pending",
      );
    }

    const listRef = db.collection("spotLists").doc(invite.listId);
    const listSnap = await tx.get(listRef);
    if (!listSnap.exists) {
      throw new HttpsError("not-found", "Spot list not found");
    }
    const listData = listSnap.data() || {};

    if (accept) {
      const role = invite.role === "edit" ? "edit" : "view";
      tx.update(inviteRef, {
        status: "accepted",
        respondedAt: FieldValue.serverTimestamp(),
        listName: typeof listData.name === "string" && listData.name.trim() ?
          listData.name.trim() :
          invite.listName,
      });
      tx.update(
          listRef,
          membershipUpdatesForAccept(listData, authUid, role, FieldValue),
      );
      return {
        accept: true,
        listId: invite.listId,
        inviterUid: invite.inviterUid,
        listName: typeof listData.name === "string" && listData.name.trim() ?
          listData.name.trim() :
          (invite.listName || "Untitled list"),
        role,
      };
    }

    tx.update(inviteRef, {
      status: "declined",
      respondedAt: FieldValue.serverTimestamp(),
    });
    return {
      accept: false,
      listId: invite.listId,
      inviterUid: invite.inviterUid,
      listName: invite.listName || "Untitled list",
      role: invite.role,
    };
  });

  if (result.accept) {
    const actorName = await loadActorName(db, authUid);
    await deliverNotifications({
      db,
      FieldValue,
      userIds: [result.inviterUid],
      payload: {
        notificationKind: "spot_list_invite_accepted",
        templateArgs: {
          actorName,
          listName: result.listName,
        },
        deeplinkKind: "list",
        deeplinkId: result.listId,
      },
    });
  }

  return {
    success: true,
    inviteId: inviteId.trim(),
    status: result.accept ? "accepted" : "declined",
    role: result.role,
    listId: result.listId,
  };
}

/**
 * @param {object} options
 * @return {Promise<object>}
 */
async function updateSpotListMemberRole({
  db,
  FieldValue,
  HttpsError,
  authUid,
  inviteId,
  role,
}) {
  if (!authUid) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }
  if (typeof inviteId !== "string" || !inviteId.trim()) {
    throw new HttpsError("invalid-argument", "inviteId is required");
  }
  if (!ROLES.has(role)) {
    throw new HttpsError("invalid-argument", "role must be edit or view");
  }

  const inviteRef = db.collection("spotListInvites").doc(inviteId.trim());
  await db.runTransaction(async (tx) => {
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) {
      throw new HttpsError("not-found", "Invite not found");
    }
    const invite = inviteSnap.data() || {};
    const listRef = db.collection("spotLists").doc(invite.listId);
    const listSnap = await tx.get(listRef);
    if (!listSnap.exists) {
      throw new HttpsError("not-found", "Spot list not found");
    }
    const listData = listSnap.data() || {};
    if (listData.createdBy !== authUid) {
      throw new HttpsError(
          "permission-denied",
          "Only the list owner can change roles",
      );
    }
    if (invite.status !== "accepted") {
      throw new HttpsError(
          "failed-precondition",
          "Only accepted members can change role",
      );
    }
    if (invite.role === role) {
      return;
    }

    tx.update(inviteRef, {role});
    tx.update(
        listRef,
        membershipUpdatesForAccept(
            listData,
            invite.inviteeUid,
            role,
            FieldValue,
        ),
    );
  });

  return {success: true, inviteId: inviteId.trim(), role};
}

/**
 * @param {object} options
 * @return {Promise<object>}
 */
async function removeSpotListMember({
  db,
  FieldValue,
  HttpsError,
  authUid,
  inviteId,
}) {
  if (!authUid) {
    throw new HttpsError("unauthenticated", "Sign in required");
  }
  if (typeof inviteId !== "string" || !inviteId.trim()) {
    throw new HttpsError("invalid-argument", "inviteId is required");
  }

  const inviteRef = db.collection("spotListInvites").doc(inviteId.trim());
  const outcome = await db.runTransaction(async (tx) => {
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) {
      throw new HttpsError("not-found", "Invite not found");
    }
    const invite = inviteSnap.data() || {};
    const listRef = db.collection("spotLists").doc(invite.listId);
    const listSnap = await tx.get(listRef);
    if (!listSnap.exists) {
      throw new HttpsError("not-found", "Spot list not found");
    }
    const listData = listSnap.data() || {};
    const isOwner = listData.createdBy === authUid;
    const isSelf = invite.inviteeUid === authUid;
    if (!isOwner && !isSelf) {
      throw new HttpsError(
          "permission-denied",
          "You can only remove yourself or manage your own list",
      );
    }
    if (!ACTIVE_STATUSES.has(invite.status)) {
      throw new HttpsError(
          "failed-precondition",
          "Invite is no longer active",
      );
    }

    const newStatus = isSelf && !isOwner ?
      (invite.status === "pending" ? "declined" : "left") :
      "revoked";

    tx.update(inviteRef, {
      status: newStatus,
      respondedAt: FieldValue.serverTimestamp(),
    });

    if (invite.status === "accepted") {
      tx.update(listRef, {
        editorIds: FieldValue.arrayRemove(invite.inviteeUid),
        viewerIds: FieldValue.arrayRemove(invite.inviteeUid),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    return {status: newStatus, listId: invite.listId};
  });

  return {
    success: true,
    inviteId: inviteId.trim(),
    status: outcome.status,
    listId: outcome.listId,
  };
}

module.exports = {
  extractUserIdOrUsername,
  resolveInviteeUid,
  inviteToSpotList,
  respondToSpotListInvite,
  updateSpotListMemberRole,
  removeSpotListMember,
  ACTIVE_STATUSES,
  ROLES,
};
