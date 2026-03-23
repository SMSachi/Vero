-- Vero App - Supabase Database Schema
-- Run this SQL in your Supabase SQL Editor (Database > SQL Editor)

-- Enable Row Level Security on all tables
-- Users can only access their own data

-- ============================================
-- WORKOUTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS workouts (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    start_date TIMESTAMPTZ NOT NULL,
    end_date TIMESTAMPTZ NOT NULL,
    duration DOUBLE PRECISION NOT NULL,
    calories INTEGER NOT NULL,
    average_heart_rate INTEGER NOT NULL,
    max_heart_rate INTEGER NOT NULL,
    intensity TEXT NOT NULL,
    interpretation TEXT,
    distance DOUBLE PRECISION,
    elevation_gain DOUBLE PRECISION,
    perceived_effort INTEGER,
    what_happened TEXT,
    what_it_means TEXT,
    what_to_do_next TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE workouts ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only access their own workouts
CREATE POLICY "Users can view own workouts" ON workouts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own workouts" ON workouts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own workouts" ON workouts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own workouts" ON workouts
    FOR DELETE USING (auth.uid() = user_id);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS workouts_user_id_idx ON workouts(user_id);
CREATE INDEX IF NOT EXISTS workouts_start_date_idx ON workouts(start_date DESC);

-- ============================================
-- DAILY CONTEXTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS daily_contexts (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    sleep_hours DOUBLE PRECISION NOT NULL,
    sleep_quality TEXT NOT NULL,
    stress_level TEXT NOT NULL,
    energy_level TEXT NOT NULL,
    resting_heart_rate INTEGER,
    hrv_score DOUBLE PRECISION,
    readiness_score INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, date)
);

-- Enable RLS
ALTER TABLE daily_contexts ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view own daily_contexts" ON daily_contexts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own daily_contexts" ON daily_contexts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own daily_contexts" ON daily_contexts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own daily_contexts" ON daily_contexts
    FOR DELETE USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS daily_contexts_user_id_idx ON daily_contexts(user_id);
CREATE INDEX IF NOT EXISTS daily_contexts_date_idx ON daily_contexts(date DESC);

-- ============================================
-- CHECK INS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS check_ins (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date TIMESTAMPTZ NOT NULL,
    mood TEXT NOT NULL,
    energy_level TEXT NOT NULL,
    soreness TEXT NOT NULL,
    motivation TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE check_ins ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view own check_ins" ON check_ins
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own check_ins" ON check_ins
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own check_ins" ON check_ins
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own check_ins" ON check_ins
    FOR DELETE USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS check_ins_user_id_idx ON check_ins(user_id);
CREATE INDEX IF NOT EXISTS check_ins_date_idx ON check_ins(date DESC);

-- ============================================
-- POST WORKOUT CHECK INS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS post_workout_check_ins (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workout_id UUID NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
    feeling TEXT NOT NULL,
    note TEXT,
    date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE post_workout_check_ins ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view own post_workout_check_ins" ON post_workout_check_ins
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own post_workout_check_ins" ON post_workout_check_ins
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own post_workout_check_ins" ON post_workout_check_ins
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own post_workout_check_ins" ON post_workout_check_ins
    FOR DELETE USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS post_workout_check_ins_user_id_idx ON post_workout_check_ins(user_id);
CREATE INDEX IF NOT EXISTS post_workout_check_ins_workout_id_idx ON post_workout_check_ins(workout_id);

-- ============================================
-- NEXT DAY RECOVERIES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS next_day_recoveries (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workout_id UUID REFERENCES workouts(id) ON DELETE SET NULL,
    date DATE NOT NULL,
    overall_score INTEGER NOT NULL,
    muscle_recovery TEXT NOT NULL,
    cardio_recovery TEXT NOT NULL,
    mental_recovery TEXT NOT NULL,
    recommendation TEXT NOT NULL,
    interpretation TEXT,
    body_feeling TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE next_day_recoveries ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view own next_day_recoveries" ON next_day_recoveries
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own next_day_recoveries" ON next_day_recoveries
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own next_day_recoveries" ON next_day_recoveries
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own next_day_recoveries" ON next_day_recoveries
    FOR DELETE USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS next_day_recoveries_user_id_idx ON next_day_recoveries(user_id);
CREATE INDEX IF NOT EXISTS next_day_recoveries_date_idx ON next_day_recoveries(date DESC);

-- ============================================
-- TREND INSIGHTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS trend_insights (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    metric TEXT NOT NULL,
    change_percentage DOUBLE PRECISION NOT NULL,
    timeframe TEXT NOT NULL,
    priority INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE trend_insights ENABLE ROW LEVEL SECURITY;

-- Policies
CREATE POLICY "Users can view own trend_insights" ON trend_insights
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own trend_insights" ON trend_insights
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own trend_insights" ON trend_insights
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own trend_insights" ON trend_insights
    FOR DELETE USING (auth.uid() = user_id);

-- Indexes
CREATE INDEX IF NOT EXISTS trend_insights_user_id_idx ON trend_insights(user_id);
CREATE INDEX IF NOT EXISTS trend_insights_created_at_idx ON trend_insights(created_at DESC);

-- ============================================
-- HELPER FUNCTION: Update updated_at timestamp
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to tables with updated_at
CREATE TRIGGER update_workouts_updated_at BEFORE UPDATE ON workouts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_daily_contexts_updated_at BEFORE UPDATE ON daily_contexts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_check_ins_updated_at BEFORE UPDATE ON check_ins
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_next_day_recoveries_updated_at BEFORE UPDATE ON next_day_recoveries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
