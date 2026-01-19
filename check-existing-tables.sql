-- Check what integration tables already exist
SELECT
    table_name,
    'EXISTS' as status
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
    'API_Connections',
    'Synced_Activities',
    'Synced_Conversations',
    'Integration_Sync_Log',
    'Coaching_Messages',
    'Coaching_Outcomes',
    'Conversation_Analyses'
)
ORDER BY table_name;
