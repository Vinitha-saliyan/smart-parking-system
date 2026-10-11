import unittest

from fastapi import HTTPException

from app.services.auth_service import (
    create_access_token,
    create_refresh_token,
    verify_token,
)


class AuthTokenTest(unittest.TestCase):
    def test_access_token_has_access_type(self) -> None:
        token = create_access_token({"sub": "user-id", "role": "ADMIN"})
        payload = verify_token(token, expected_type="access")
        self.assertEqual(payload["type"], "access")

    def test_refresh_token_has_refresh_type(self) -> None:
        token = create_refresh_token({"sub": "user-id"})
        payload = verify_token(token, expected_type="refresh")
        self.assertEqual(payload["type"], "refresh")

    def test_refresh_token_cannot_call_protected_api(self) -> None:
        token = create_refresh_token({"sub": "user-id"})
        with self.assertRaises(HTTPException):
            verify_token(token, expected_type="access")

    def test_access_token_cannot_refresh_a_session(self) -> None:
        token = create_access_token({"sub": "user-id", "role": "ADMIN"})
        with self.assertRaises(HTTPException):
            verify_token(token, expected_type="refresh")


if __name__ == "__main__":
    unittest.main()
