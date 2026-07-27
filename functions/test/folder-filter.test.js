const {
  normalizeFolderList,
  applyFolderFilter,
  sortFoldersByIncludeOrder,
} = require("../lib/folder-filter");

describe("normalizeFolderList", () => {
  it("normalizes arrays and trims empties", () => {
    expect(normalizeFolderList([" A ", "", "B"])).toEqual(["A", "B"]);
  });

  it("splits comma-separated strings", () => {
    expect(normalizeFolderList("A, B , ,C")).toEqual(["A", "B", "C"]);
  });

  it("returns empty for null/undefined/non-string", () => {
    expect(normalizeFolderList(null)).toEqual([]);
    expect(normalizeFolderList(undefined)).toEqual([]);
    expect(normalizeFolderList(42)).toEqual([]);
  });
});

describe("applyFolderFilter", () => {
  const placemarks = [
    {name: "a", folderName: "Parks", folderPath: ["Parks"]},
    {name: "b", folderName: "Gyms", folderPath: ["Gyms"]},
    {name: "c", folderName: "Rooftops", folderPath: ["Cities", "Rooftops"]},
    {name: "d", folderName: "Misc", folderPath: []},
  ];

  it("keeps all placemarks when no filter is set", () => {
    const result = applyFolderFilter(placemarks, null, null);
    expect(result.mode).toBe("none");
    expect(result.placemarks).toHaveLength(4);
  });

  it("includes only matching folderPath segments (case-insensitive)", () => {
    const result = applyFolderFilter(placemarks, ["parks", "Cities"], null);
    expect(result.mode).toBe("include");
    expect(result.placemarks.map((p) => p.name)).toEqual(["a", "c"]);
  });

  it("sorts included placemarks by includeFolders order", () => {
    const result = applyFolderFilter(
        placemarks,
        ["Rooftops", "Parks"],
        null,
    );
    expect(result.placemarks.map((p) => p.name)).toEqual(["c", "a"]);
  });

  it("excludes matching folderPath segments and keeps the rest", () => {
    const result = applyFolderFilter(placemarks, null, ["Gyms", "cities"]);
    expect(result.mode).toBe("exclude");
    expect(result.placemarks.map((p) => p.name)).toEqual(["a", "d"]);
  });

  it("prefers include when both include and exclude are set", () => {
    const warnSpy = jest.spyOn(console, "warn").mockImplementation(() => {});
    const result = applyFolderFilter(placemarks, ["Parks"], ["Parks"]);
    expect(result.mode).toBe("include");
    expect(result.placemarks.map((p) => p.name)).toEqual(["a"]);
    expect(warnSpy).toHaveBeenCalled();
    warnSpy.mockRestore();
  });
});

describe("sortFoldersByIncludeOrder", () => {
  it("orders by include list then alphabetically", () => {
    expect(
        sortFoldersByIncludeOrder(["Zeta", "Alpha", "Beta"], ["Beta", "Zeta"]),
    ).toEqual(["Beta", "Zeta", "Alpha"]);
  });

  it("sorts alphabetically when include list is empty", () => {
    expect(sortFoldersByIncludeOrder(["c", "a", "b"], [])).toEqual([
      "a",
      "b",
      "c",
    ]);
  });
});
