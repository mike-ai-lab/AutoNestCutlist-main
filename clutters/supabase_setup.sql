-- Add report_jobs table to existing database
CREATE TABLE IF NOT EXISTS report_jobs (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  task_id TEXT NOT NULL,
  task_name TEXT NOT NULL,
  file_url TEXT NOT NULL,
  email TEXT NOT NULL,
  format TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  processed_at TIMESTAMP WITH TIME ZONE,
  status TEXT DEFAULT 'pending'
);

-- Enable RLS
ALTER TABLE report_jobs ENABLE ROW LEVEL SECURITY;

-- Create policy for inserting report jobs
DROP POLICY IF EXISTS "Allow insert report jobs" ON report_jobs;
CREATE POLICY "Allow insert report jobs" ON report_jobs
  FOR INSERT WITH CHECK (true);

-- Create policy for reading report jobs
DROP POLICY IF EXISTS "Allow read report jobs" ON report_jobs;
CREATE POLICY "Allow read report jobs" ON report_jobs
  FOR SELECT USING (true);

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_report_jobs_status ON report_jobs(status);
CREATE INDEX IF NOT EXISTS idx_report_jobs_created_at ON report_jobs(created_at);