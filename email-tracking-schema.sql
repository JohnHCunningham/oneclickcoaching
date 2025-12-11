-- Email Tracking Table for Sandler Email Generator
CREATE TABLE IF NOT EXISTS Email_Tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prospect_name TEXT NOT NULL,
    prospect_company TEXT NOT NULL,
    subject_line TEXT NOT NULL,
    email_style TEXT NOT NULL, -- 'soft' or 'bold'
    sent_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT DEFAULT 'sent', -- 'sent', 'opened', 'responded', 'booked', 'no_response'
    response_date DATE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_email_tracking_sent_date ON Email_Tracking(sent_date);
CREATE INDEX IF NOT EXISTS idx_email_tracking_status ON Email_Tracking(status);

-- Enable Row Level Security
ALTER TABLE Email_Tracking ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all operations (adjust based on your auth setup)
CREATE POLICY "Allow all operations on Email_Tracking" ON Email_Tracking
    FOR ALL USING (true) WITH CHECK (true);
