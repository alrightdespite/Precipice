-- Sha256 tests — verifies the pure-Luau implementation against published vectors
-- (NIST SHA-256 + RFC 4231 HMAC-SHA256). If these pass, the implementation is correct.

local spec = require("../spec")
local Sha256 = require("../../src/shared/Core/Sha256")

spec.describe("Sha256.hash — NIST vectors", function()
	spec.it("hashes the empty string", function()
		spec.expect(Sha256.hash("")).toBe("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
	end)

	spec.it("hashes 'abc'", function()
		spec.expect(Sha256.hash("abc")).toBe("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
	end)

	spec.it("hashes a 56-byte message (two-block padding boundary)", function()
		local msg = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
		spec.expect(Sha256.hash(msg)).toBe("248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1")
	end)
end)

spec.describe("Sha256.hmac — RFC 4231 vectors", function()
	spec.it("test case 1 (20-byte 0x0b key, 'Hi There')", function()
		local key = string.rep(string.char(0x0b), 20)
		spec.expect(Sha256.hmac(key, "Hi There")).toBe("b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7")
	end)

	spec.it("test case 2 ('Jefe', 'what do ya want for nothing?')", function()
		spec
			.expect(Sha256.hmac("Jefe", "what do ya want for nothing?"))
			.toBe("5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843")
	end)

	spec.it("test case 6 (131-byte key → key is hashed first)", function()
		local key = string.rep(string.char(0xaa), 131)
		local data = "Test Using Larger Than Block-Size Key - Hash Key First"
		spec.expect(Sha256.hmac(key, data)).toBe("60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54")
	end)
end)
