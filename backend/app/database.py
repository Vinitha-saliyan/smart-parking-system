from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from app.config import settings
from app.database_migrations import run_compatibility_migrations

engine = create_async_engine(settings.DATABASE_URL, echo=False)
AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

Base = declarative_base()

async def get_db():
    """Dependency for getting async database session."""
    async with AsyncSessionLocal() as session:
        yield session

async def init_db():
    """Initialize database tables."""
    # Import every model before create_all so newly added tables are registered.
    import app.models  # noqa: F401

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await run_compatibility_migrations(conn)
