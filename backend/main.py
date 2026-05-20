from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import agent, reviews, bookings, auth, chat
from agents.timer_agent import scheduler
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler.start()
    yield
    scheduler.shutdown()

app = FastAPI(title="Karobar AI API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth", tags=["Auth"])
app.include_router(agent.router, prefix="/agent", tags=["Agents"])
app.include_router(reviews.router, prefix="/reviews", tags=["Reviews"])
app.include_router(bookings.router, prefix="/bookings", tags=["Bookings"])
app.include_router(chat.router, prefix="/chat", tags=["Chat"])

@app.get("/")
async def root():
    return {"message": "Karobar AI API is running"}
