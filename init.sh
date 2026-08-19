#!/bin/bash
set -euo pipefail

echo "=== Bootstrapping dev environment ==="

# Backend dependencies
if [ -d "backend" ]; then
  cd backend && uv sync && cd ..
else
  echo "backend/ not generated yet — skipping backend install"
fi

# Frontend dependencies
if [ -d "frontend" ]; then
  cd frontend && npm ci && cd ..
else
  echo "frontend/ not generated yet — skipping frontend install"
fi

# Environment
if [ -f ".env.example" ] && [ ! -f ".env" ]; then
  cp .env.example .env
  echo "Created .env from .env.example — add your API keys"
fi

# Database migrations + seed data (SQLite, append-only migrations)
if [ -d "backend/migrations" ]; then
  cd backend && uv run alembic upgrade head && cd ..
fi
if [ -f "backend/scripts/seed.py" ]; then
  cd backend && uv run python scripts/seed.py && cd ..
fi

# Start local dev servers
if [ -d "backend" ]; then
  cd backend && uv run uvicorn src.main:app --host 0.0.0.0 --port 8000 &
  cd ..
fi
if [ -d "frontend" ]; then
  cd frontend && npm run dev -- --port 3000 &
  cd ..
fi

# Health checks
echo "Waiting for services..."
for i in $(seq 1 5); do
  if curl -fsS http://localhost:8000/health >/dev/null 2>&1; then
    echo "  backend  http://localhost:8000  OK"
    break
  fi
  [ "$i" = "5" ] && echo "  backend  http://localhost:8000  FAILED"
  sleep 2
done

for i in $(seq 1 5); do
  if curl -fsS http://localhost:3000 >/dev/null 2>&1; then
    echo "  frontend http://localhost:3000  OK"
    break
  fi
  [ "$i" = "5" ] && echo "  frontend http://localhost:3000  FAILED"
  sleep 2
done

echo "=== Environment ready ==="
echo "API:  http://localhost:8000  (docs at /docs)"
echo "UI:   http://localhost:3000"
