describe("Dependency Libraries Check", function() {
    it("JQuery check", function() {
        expect((jQuery || $)).toBeDefined();
    });
    it("Underscore check", function() {
        expect(_).toBeDefined();
    });
});