-- Insio Health - Supabase Database Schema
-- Run this SQL in your Supabase SQL Editor (Database > SQL Editor)
--
-- TABLES:
-- 1. workouts - workout sessions
-- 2. daily_contexts - daily tracking (sleep, water, nutrition, weight)
-- 3. check_ins - general mood/energy check-ins
-- 4. post_workout_check_ins - how workout felt (linked to workout)
-- 5. next_day_recoveries - next-day recovery tracking
-- 6. trend_insights - computed trend data
--
-- Run each section separately if you get errors.

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
    average_heart_rate INTEGER,
    max_heart_rate INTEGER,
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

ALTER TABLE workouts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own workouts" ON workouts;
DROP POLICY IF EXISTS "Users can insert own workouts" ON workouts;
DROP POLICY IF EXISTS "Users can update own workouts" ON workouts;
DROP POLICY IF EXISTS "Users can delete own workouts" ON workouts;

CREATE POLICY "Users can view own workouts" ON workouts
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own workouts" ON workouts
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own workouts" ON workouts
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own workouts" ON workouts
    FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS workouts_user_id_idx ON workouts(user_id);
CREATE INDEX IF NOT EXISTS workouts_start_date_idx ON workouts(start_date DESC);

-- ============================================
-- DAILY CONTEXTS TABLE (Extended with nutrition/weight)
-- ============================================
CREATE TABLE IF NOT EXISTS daily_contexts (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    -- Sleep
    sleep_hours DOUBLE PRECISION,
    sleep_quality TEXT,
    -- Energy/Stress
    stress_level TEXT,
    energy_level TEXT,
    -- Biometrics
    resting_heart_rate INTEGER,
    hrv_score DOUBLE PRECISION,
    readiness_score INTEGER,
    -- Nutrition (new)
    water_ml INTEGER,
    calories INTEGER,
    protein_grams INTEGER,
    carbs_grams INTEGER,
    fat_grams INTEGER,
    sodium_mg INTEGER,
    -- Weight (new - only tracked if goal == weight_loss)
    weight_kg DOUBLE PRECISION,
    body_fat_percentage DOUBLE PRECISION,
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, date)
);

ALTER TABLE daily_contexts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own daily_contexts" ON daily_contexts;
DROP POLICY IF EXISTS "Users can insert own daily_contexts" ON daily_contexts;
DROP POLICY IF EXISTS "Users can update own daily_contexts" ON daily_contexts;
DROP POLICY IF EXISTS "Users can delete own daily_contexts" ON daily_contexts;

CREATE POLICY "Users can view own daily_contexts" ON daily_contexts
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own daily_contexts" ON daily_contexts
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own daily_contexts" ON daily_contexts
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own daily_contexts" ON daily_contexts
    FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS daily_contexts_user_id_idx ON daily_contexts(user_id);
CREATE INDEX IF NOT EXISTS daily_contexts_date_idx ON daily_contexts(date DESC);

-- ============================================
-- CHECK INS TABLE (General mood/energy)
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

ALTER TABLE check_ins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own check_ins" ON check_ins;
DROP POLICY IF EXISTS "Users can insert own check_ins" ON check_ins;
DROP POLICY IF EXISTS "Users can update own check_ins" ON check_ins;
DROP POLICY IF EXISTS "Users can delete own check_ins" ON check_ins;

CREATE POLICY "Users can view own check_ins" ON check_ins
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own check_ins" ON check_ins
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own check_ins" ON check_ins
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own check_ins" ON check_ins
    FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS check_ins_user_id_idx ON check_ins(user_id);
CREATE INDEX IF NOT EXISTS check_ins_date_idx ON check_ins(date DESC);

-- ============================================
-- POST WORKOUT CHECK INS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS post_workout_check_ins (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    workout_id UUID REFERENCES workouts(id) ON DELETE CASCADE,
    feeling TEXT NOT NULL,
    note TEXT,
    date TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE post_workout_check_ins ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own post_workout_check_ins" ON post_workout_check_ins;
DROP POLICY IF EXISTS "Users can insert own post_workout_check_ins" ON post_workout_check_ins;
DROP POLICY IF EXISTS "Users can update own post_workout_check_ins" ON post_workout_check_ins;
DROP POLICY IF EXISTS "Users can delete own post_workout_check_ins" ON post_workout_check_ins;

CREATE POLICY "Users can view own post_workout_check_ins" ON post_workout_check_ins
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own post_workout_check_ins" ON post_workout_check_ins
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own post_workout_check_ins" ON post_workout_check_ins
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own post_workout_check_ins" ON post_workout_check_ins
    FOR DELETE USING (auth.uid() = user_id);

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

ALTER TABLE next_day_recoveries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own next_day_recoveries" ON next_day_recoveries;
DROP POLICY IF EXISTS "Users can insert own next_day_recoveries" ON next_day_recoveries;
DROP POLICY IF EXISTS "Users can update own next_day_recoveries" ON next_day_recoveries;
DROP POLICY IF EXISTS "Users can delete own next_day_recoveries" ON next_day_recoveries;

CREATE POLICY "Users can view own next_day_recoveries" ON next_day_recoveries
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own next_day_recoveries" ON next_day_recoveries
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own next_day_recoveries" ON next_day_recoveries
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own next_day_recoveries" ON next_day_recoveries
    FOR DELETE USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS next_day_recoveries_user_id_idx ON next_day_recoveries(user_id);
CREATE INDEX IF NOT EXISTS next_day_recoveries_date_idx ON next_day_recoveries(date DESC);

-- ============================================
-- USER GOALS TABLE (New - stores fitness goals)
-- ============================================
CREATE TABLE IF NOT EXISTS user_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    goal_type TEXT NOT NULL, -- 'weight_loss', 'muscle_gain', 'endurance', 'general_fitness', 'maintenance'
    target_weight_kg DOUBLE PRECISION,
    target_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

ALTER TABLE user_goals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own user_goals" ON user_goals
    FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own user_goals" ON user_goals
    FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can update own user_goals" ON user_goals
    FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can delete own user_goals" ON user_goals
    FOR DELETE USING (auth.uid() = user_id);

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

-- Apply triggers (drop first to avoid duplicates)
DROP TRIGGER IF EXISTS update_workouts_updated_at ON workouts;
DROP TRIGGER IF EXISTS update_daily_contexts_updated_at ON daily_contexts;
DROP TRIGGER IF EXISTS update_check_ins_updated_at ON check_ins;
DROP TRIGGER IF EXISTS update_next_day_recoveries_updated_at ON next_day_recoveries;
DROP TRIGGER IF EXISTS update_user_goals_updated_at ON user_goals;

CREATE TRIGGER update_workouts_updated_at BEFORE UPDATE ON workouts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_daily_contexts_updated_at BEFORE UPDATE ON daily_contexts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_check_ins_updated_at BEFORE UPDATE ON check_ins
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_next_day_recoveries_updated_at BEFORE UPDATE ON next_day_recoveries
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_goals_updated_at BEFORE UPDATE ON user_goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- MIGRATION: Add new columns to existing tables
-- Run this if you already have the tables
-- ============================================

-- Add nutrition columns to daily_contexts if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'daily_contexts' AND column_name = 'water_ml') THEN
        ALTER TABLE daily_contexts ADD COLUMN water_ml INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'daily_contexts' AND column_name = 'calories') THEN
        ALTER TABLE daily_contexts ADD COLUMN calories INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'daily_contexts' AND column_name = 'protein_grams') THEN
        ALTER TABLE daily_contexts ADD COLUMN protein_grams INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'daily_contexts' AND column_name = 'carbs_grams') THEN
        ALTER TABLE daily_contexts ADD COLUMN carbs_grams INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'daily_contexts' AND column_name = 'fat_grams') THEN
        ALTER TABLE daily_contexts ADD COLUMN fat_grams INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'daily_contexts' AND column_name = 'sodium_mg') THEN
        ALTER TABLE daily_contexts ADD COLUMN sodium_mg INTEGER;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'daily_contexts' AND column_name = 'weight_kg') THEN
        ALTER TABLE daily_contexts ADD COLUMN weight_kg DOUBLE PRECISION;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'daily_contexts' AND column_name = 'body_fat_percentage') THEN
        ALTER TABLE daily_contexts ADD COLUMN body_fat_percentage DOUBLE PRECISION;
    END IF;
END $$;

-- Make some columns nullable for flexibility
ALTER TABLE daily_contexts ALTER COLUMN sleep_hours DROP NOT NULL;
ALTER TABLE daily_contexts ALTER COLUMN sleep_quality DROP NOT NULL;
ALTER TABLE daily_contexts ALTER COLUMN stress_level DROP NOT NULL;
ALTER TABLE daily_contexts ALTER COLUMN energy_level DROP NOT NULL;
ALTER TABLE daily_contexts ALTER COLUMN readiness_score DROP NOT NULL;
