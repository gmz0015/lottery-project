from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "sqlite:///./lottery.db"
    api_token: str = "change-me-token"
    admin_password: str = "change-me-pass"
    read_requires_auth: bool = True
    cors_origins: str = "*"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
