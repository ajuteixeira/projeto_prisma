-- Tabela para armazenar as conexões de plataformas (SEM AUTENTICAÇÃO)
-- Execute este SQL no Supabase SQL Editor

CREATE TABLE IF NOT EXISTS user_connections (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id TEXT NOT NULL UNIQUE,
    steam_connected BOOLEAN DEFAULT FALSE,
    psn_connected BOOLEAN DEFAULT FALSE,
    xbox_connected BOOLEAN DEFAULT FALSE,
    retroarch_connected BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Criar índice para melhorar performance de consultas por session_id
CREATE INDEX IF NOT EXISTS idx_user_connections_session_id ON user_connections(session_id);

-- DESABILITAR Row Level Security (RLS) para acesso público
ALTER TABLE user_connections DISABLE ROW LEVEL SECURITY;

-- Remover todas as políticas existentes
DROP POLICY IF EXISTS "Users can view their own connections" ON user_connections;
DROP POLICY IF EXISTS "Users can insert their own connections" ON user_connections;
DROP POLICY IF EXISTS "Users can update their own connections" ON user_connections;
DROP POLICY IF EXISTS "Users can delete their own connections" ON user_connections;

-- Função para atualizar automaticamente o campo updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar updated_at automaticamente
DROP TRIGGER IF EXISTS update_user_connections_updated_at ON user_connections;
CREATE TRIGGER update_user_connections_updated_at
    BEFORE UPDATE ON user_connections
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Comentários para documentação
COMMENT ON TABLE user_connections IS 'Armazena as conexões de plataformas de jogos (sem autenticação)';
COMMENT ON COLUMN user_connections.session_id IS 'ID único da sessão do navegador (gerado no cliente)';
COMMENT ON COLUMN user_connections.steam_connected IS 'Indica se a conta Steam está conectada';
COMMENT ON COLUMN user_connections.psn_connected IS 'Indica se a conta PlayStation Network está conectada';
COMMENT ON COLUMN user_connections.xbox_connected IS 'Indica se a conta Xbox Live está conectada';
COMMENT ON COLUMN user_connections.retroarch_connected IS 'Indica se a conta RetroAchievements está conectada';

-- NOTA IMPORTANTE:
-- Esta configuração permite acesso público à tabela.
-- Considere adicionar Rate Limiting ou outras proteções no Supabase
-- para evitar abuso da API.
