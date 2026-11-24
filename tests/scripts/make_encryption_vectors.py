#!/usr/bin/env python3
"""Writes tests/Tests/SurveyLogicTests/Fixtures/encryption_vectors.json.

Expected values come from the openssl CLI (AES) and Python big-int math (textbook RSA, as the backend's
libs/encryption.py does), not from the app's Swift code, so the Swift tests compare two independent
implementations. Stdlib + openssl only. Keeps the existing test key unless --new-key is given.

usage: python3 tests/scripts/make_encryption_vectors.py [--new-key]
"""
import base64
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile

OUT = os.path.join(os.path.dirname(__file__), "..", "Tests", "SurveyLogicTests", "Fixtures", "encryption_vectors.json")


def b64url(b: bytes) -> str:
    # the app's mapping: std base64, `/`->`_`, `+`->`-`, `=` kept
    return base64.b64encode(b).decode().replace("/", "_").replace("+", "-")


def openssl(*args: str, data: bytes = b"") -> bytes:
    return subprocess.run(["openssl", *args], input=data, capture_output=True, check=True).stdout


def aes_cbc_pkcs7(key: bytes, iv: bytes, plain: bytes) -> bytes:
    return openssl("enc", "-aes-128-cbc", "-K", key.hex(), "-iv", iv.hex(), data=plain)


def new_key() -> dict:
    with tempfile.TemporaryDirectory() as d:
        pem = os.path.join(d, "k.pem")
        openssl("genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048", "-out", pem)
        # PKCS#1 DER is what SecKeyCreateWithData takes for an RSA private key
        der = openssl("rsa", "-in", pem, "-outform", "DER", "-traditional")
        # backend format: PEM SubjectPublicKeyInfo body lines joined (libs/rsa.py prepare_X509_key_for_java)
        pub_pem = openssl("rsa", "-in", pem, "-pubout").decode()
        text = openssl("rsa", "-in", pem, "-noout", "-text").decode()
    pub = "".join(pub_pem.strip().split("\n")[1:-1])

    def hexfield(name: str) -> str:
        m = re.search(name + r":\s*\n((?:\s+[0-9a-f:]+\n)+)", text)
        return m.group(1).replace(":", "").replace(" ", "").replace("\n", "").lstrip("0") or "0"

    return {
        "public_key_base64": pub,
        "private_key_pkcs1_der_base64": base64.b64encode(der).decode(),
        "n_hex": hexfield("modulus"),
        "e": 65537,
        "d_hex": hexfield("privateExponent"),
    }


def main() -> None:
    old = None
    if os.path.exists(OUT) and "--new-key" not in sys.argv:
        with open(OUT) as f:
            old = json.load(f)["rsa"]
    rsa = old or new_key()
    n, e = int(rsa["n_hex"], 16), rsa["e"]
    size = (n.bit_length() + 7) // 8

    def key_line(aes_key: bytes) -> str:
        # raw RSA, no padding, of the utf8 of base64url(aesKey)
        m = int.from_bytes(b64url(aes_key).encode(), "big")
        return b64url(pow(m, e, n).to_bytes(size, "big")) + "\n"

    def leading_zero_key() -> bytes:
        # first key (counting up) whose RSA ciphertext starts with a 0x00 byte, ~1 in 256 keys; the backend notes
        # failures on such blobs (extract_aes_key), so pin one
        i = 0
        while True:
            k = i.to_bytes(16, "big")
            m = int.from_bytes(b64url(k).encode(), "big")
            if pow(m, e, n).to_bytes(size, "big")[0] == 0:
                return k
            i += 1

    key1 = bytes(range(16))
    key2 = bytes.fromhex("fbefbeffffff00112233445566778899")  # base64 has `+`, `/` and `=`
    iv1 = bytes(range(0xA0, 0xB0))
    iv2 = bytes.fromhex("fbffbffbffbf0000000000000000ffff")

    lines = [
        ("csv header", key1, iv1, "timestamp,UTC time,accuracy,altitude,latitude,longitude"),
        ("empty line", key1, iv1, ""),
        ("exactly one block", key1, iv1, "0123456789abcdef"),
        ("unicode", key2, iv2, "über,日本語,🙂,emoji"),
        ("embedded newline", key2, iv2, "row one\nrow two"),
        ("long line", key2, iv1, ",".join(str(i * 1.5) for i in range(120))),
    ]
    audio_plain = bytes((i * 7 + 3) % 256 for i in range(1000))

    out = {
        "_comment": "Test-only RSA key, generated for tests/ by tests/scripts/make_encryption_vectors.py; protects "
                    "nothing, never use it outside tests. Expected values come from openssl + Python, not the app.",
        "rsa": rsa,
        "base64url": [
            {"bytes_hex": "fbefbeffffff", "expected": b64url(bytes.fromhex("fbefbeffffff"))},
            {"bytes_hex": "fbff", "expected": b64url(bytes.fromhex("fbff"))},
            {"bytes_hex": "", "expected": ""},
        ],
        "key_lines": [{"aes_key_hex": k.hex(), "expected": key_line(k)} for k in (key1, key2, leading_zero_key())],
        "data_lines": [
            {"name": name, "aes_key_hex": k.hex(), "iv_hex": iv.hex(), "plaintext": text,
             "expected": b64url(iv) + ":" + b64url(aes_cbc_pkcs7(k, iv, text.encode())) + "\n"}
            for name, k, iv, text in lines
        ],
        "audio": [{
            "aes_key_hex": key2.hex(), "iv_hex": iv2.hex(), "plaintext_hex": audio_plain.hex(),
            "expected_iv_header": b64url(iv2) + ":",
            "expected_body": b64url(aes_cbc_pkcs7(key2, iv2, audio_plain)),
        }],
        "password_sha256": [
            {"password": p, "expected": b64url(hashlib.sha256(p.encode()).digest())}
            for p in ("abcdefgh", "pässwörd 🙂")
        ],
    }
    with open(OUT, "w") as f:
        json.dump(out, f, indent=2, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    main()
