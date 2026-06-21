-- Sha256: pure-Luau SHA-256 + HMAC-SHA256 (no Roblox globals, Lune-testable).
-- Verified against published test vectors (NIST SHA-256 + RFC 4231 HMAC) in
-- tests/specs/Sha256.luau. Used by SeedResolver for the weekly seed HMAC.

local band = bit32.band
local bxor = bit32.bxor
local bnot = bit32.bnot
local rrotate = bit32.rrotate
local rshift = bit32.rshift
local lshift = bit32.lshift

local MOD = 0x100000000

-- Round constants (first 32 bits of the fractional parts of the cube roots of the
-- first 64 primes).
local K = {
	0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
	0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
	0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
	0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
	0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
	0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
	0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
	0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local Sha256 = {}

-- Returns the raw 32-byte digest of `message` as a binary string.
local function digestBytes(message: string): string
	-- Initial hash values (fractional parts of the square roots of the first 8 primes).
	local h0, h1, h2, h3 = 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a
	local h4, h5, h6, h7 = 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

	-- Padding: 0x80, then zeros to 56 mod 64, then the 64-bit big-endian bit length.
	local msgLen = #message
	local bitLen = msgLen * 8
	local padded = message .. "\128"
	while #padded % 64 ~= 56 do
		padded = padded .. "\0"
	end
	-- 64-bit length, big-endian. Bit length fits in 53-bit doubles for any real input.
	local lenBytes = ""
	for i = 7, 0, -1 do
		lenBytes = lenBytes .. string.char(math.floor(bitLen / (256 ^ i)) % 256)
	end
	padded = padded .. lenBytes

	local w = {}
	for chunkStart = 1, #padded, 64 do
		-- Build the first 16 words from the 64-byte chunk (big-endian).
		for i = 0, 15 do
			local j = chunkStart + i * 4
			local b1, b2, b3, b4 = string.byte(padded, j, j + 3)
			w[i + 1] = lshift(b1, 24) + lshift(b2, 16) + lshift(b3, 8) + b4
		end
		-- Extend to 64 words.
		for i = 17, 64 do
			local v15 = w[i - 15]
			local v2 = w[i - 2]
			local s0 = bxor(rrotate(v15, 7), rrotate(v15, 18), rshift(v15, 3))
			local s1 = bxor(rrotate(v2, 17), rrotate(v2, 19), rshift(v2, 10))
			w[i] = (w[i - 16] + s0 + w[i - 7] + s1) % MOD
		end

		local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7
		for i = 1, 64 do
			local S1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
			local ch = bxor(band(e, f), band(bnot(e), g))
			local temp1 = (h + S1 + ch + K[i] + w[i]) % MOD
			local S0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
			local maj = bxor(band(a, b), band(a, c), band(b, c))
			local temp2 = (S0 + maj) % MOD
			h = g
			g = f
			f = e
			e = (d + temp1) % MOD
			d = c
			c = b
			b = a
			a = (temp1 + temp2) % MOD
		end

		h0 = (h0 + a) % MOD
		h1 = (h1 + b) % MOD
		h2 = (h2 + c) % MOD
		h3 = (h3 + d) % MOD
		h4 = (h4 + e) % MOD
		h5 = (h5 + f) % MOD
		h6 = (h6 + g) % MOD
		h7 = (h7 + h) % MOD
	end

	local function word(x: number): string
		return string.char(
			band(rshift(x, 24), 0xFF),
			band(rshift(x, 16), 0xFF),
			band(rshift(x, 8), 0xFF),
			band(x, 0xFF)
		)
	end
	return word(h0) .. word(h1) .. word(h2) .. word(h3) .. word(h4) .. word(h5) .. word(h6) .. word(h7)
end

local function toHex(bytes: string): string
	return (bytes:gsub(".", function(c)
		return string.format("%02x", string.byte(c))
	end))
end

-- Hex digest of a message.
function Sha256.hash(message: string): string
	return toHex(digestBytes(message))
end

-- Raw 32-byte digest of a message.
function Sha256.hashBytes(message: string): string
	return digestBytes(message)
end

-- HMAC-SHA256(key, message) → hex digest. Block size for SHA-256 is 64 bytes.
function Sha256.hmac(key: string, message: string): string
	if #key > 64 then
		key = digestBytes(key)
	end
	-- Pad key to 64 bytes.
	key = key .. string.rep("\0", 64 - #key)
	local oKeyPad = key:gsub(".", function(c)
		return string.char(bxor(string.byte(c), 0x5c))
	end)
	local iKeyPad = key:gsub(".", function(c)
		return string.char(bxor(string.byte(c), 0x36))
	end)
	return toHex(digestBytes(oKeyPad .. digestBytes(iKeyPad .. message)))
end

return Sha256
