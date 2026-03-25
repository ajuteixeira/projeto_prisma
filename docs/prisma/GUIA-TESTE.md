# 🧪 Guia de Teste - Projeto Prisma

## Como Testar a Reorganização

### 1. Abrir no Navegador

#### Método 1: Live Server (Recomendado)
1. Instale a extensão "Live Server" no VS Code
2. Clique com botão direito em `dashboard.html` ou `profile.html`
3. Selecione "Open with Live Server"
4. O navegador abrirá automaticamente

#### Método 2: Diretamente no Navegador
1. Navegue até a pasta do projeto
2. Arraste `dashboard.html` ou `profile.html` para o navegador
3. **⚠️ Nota**: Alguns recursos podem não funcionar por restrições CORS

### 2. Checklist de Testes

#### ✅ Dashboard (dashboard.html)

**Efeitos Visuais:**
- [ ] Prisma background com feixes de luz animados
- [ ] Partículas flutuando na tela
- [ ] Scrollbar customizada (azul)
- [ ] Cards com efeito shimmer ao passar mouse

**Navegação Sidebar:**
- [ ] Ícone Dashboard (gamepad) ativo por padrão
- [ ] Clicar em Ranking (troféu) - *ainda não implementado*
- [ ] Clicar em Followers (usuário) - muda para página de seguidores
- [ ] Clicar em Settings (engrenagem) - muda para página de configurações

**Seguidores/Seguindo:**
- [ ] Abas funcionando (Seguidores, Seguindo, Pesquisar)
- [ ] Botão "Seguir" muda para "Deixar de seguir"
- [ ] Contador de "Seguindo" atualiza corretamente
- [ ] Pesquisa filtra usuários em tempo real
- [ ] Clicar no card do usuário navega para profile.html

**Modais:**
- [ ] Modal de Logout abre ao clicar em "Sair"
- [ ] Modal de Delete abre ao clicar em "Excluir"
- [ ] Modal de Delete exige digitar "EXCLUIR" para confirmar
- [ ] Botões de fechar funcionam corretamente

**Conquistas:**
- [ ] 4 conquistas fixadas aparecem no perfil
- [ ] Botão "Gerenciar" existe (funcionalidade futura)

**Jogos Recentes:**
- [ ] Tabela de jogos renderiza corretamente
- [ ] Progress bars animam ao carregar
- [ ] Badges de plataforma aparecem
- [ ] Hover nos jogos funciona

#### ✅ Profile (profile.html?username=carly)

**URL Parameters:**
- [ ] Abrir `profile.html?username=carly` - Mostra perfil da Carly
- [ ] Abrir `profile.html?username=cipher.pro` - Mostra perfil do Cypher
- [ ] Username inválido mostra erro

**Efeitos Visuais:**
- [ ] Prisma background igual ao dashboard
- [ ] Partículas flutuando
- [ ] Background consistente com dashboard

**Botão Seguir:**
- [ ] Botão aparece APENAS se NÃO estiver seguindo
- [ ] Clicar em "Seguir" esconde o botão
- [ ] Notificação "Seguindo @username" aparece
- [ ] Notificação desaparece após 3 segundos

**Dados do Perfil:**
- [ ] Avatar carrega corretamente
- [ ] Nome e username aparecem
- [ ] Contadores de seguidores/seguindo aparecem
- [ ] Borda do avatar tem cor correta (cada perfil tem cor única)

**Integração com Dashboard:**
- [ ] Se seguir no profile.html, aparece como "seguindo" no dashboard
- [ ] localStorage persiste entre páginas
- [ ] Contadores sincronizados

### 3. Testes de Console

Abra o Console do Navegador (F12) e execute:

#### Verificar localStorage
```javascript
// Ver quem você está seguindo
console.log(localStorage.getItem('following'));

// Limpar follows
localStorage.removeItem('following');

// Adicionar follow manualmente
localStorage.setItem('following', JSON.stringify(['cipher.pro', 'nova.star']));
```

#### Verificar platformStats
```javascript
// Ver configuração das plataformas
console.log(platformStats);
```

#### Testar Prisma Effect
```javascript
// Deve ter 4 beams + 1 core
document.querySelectorAll('.light-beam').length; // Deve retornar 4
```

### 4. Testes de Responsividade

#### Desktop (1920x1080)
- [ ] Layout em 3 colunas funciona
- [ ] Sidebar visível
- [ ] Cards bem espaçados

#### Tablet (768px)
- [ ] Layout em 2 colunas
- [ ] Sidebar compacta
- [ ] Cards responsivos

#### Mobile (375px)
- [ ] Layout em 1 coluna
- [ ] Sidebar em hamburger menu (futuro)
- [ ] Cards empilhados

### 5. Testes de Performance

#### Verificar no DevTools (F12 → Network)
- [ ] Todos os CSS carregam (6 arquivos para dashboard)
- [ ] Todos os JS carregam (3 arquivos para dashboard)
- [ ] Sem erros 404
- [ ] Tempo de carregamento < 1s

#### Verificar no DevTools (F12 → Console)
- [ ] Sem erros JavaScript
- [ ] Sem warnings importantes
- [ ] Funções globais disponíveis

### 6. Bugs Conhecidos

#### ⚠️ Para Resolver
- [ ] Ranking page ainda não implementada
- [ ] Modal de editar perfil abre mas não salva
- [ ] Modal de Pin Achievements não gerencia pins
- [ ] Onboarding não conectado ao fluxo

### 7. Comparação Antes/Depois

#### Teste de Carga (F5)
**Antes (monolítico):**
- dashboard.html: ~150 KB
- profile.html: ~50 KB
- Total: ~200 KB por navegação

**Depois (modular):**
- dashboard.html: ~47 KB
- CSS (cached): ~18 KB (primeira vez)
- JS (cached): ~21 KB (primeira vez)
- Total primeira vez: ~86 KB
- Total depois: ~47 KB (cache)
- **Economia: 76% após cache**

### 8. Comandos Úteis

#### Abrir dashboard no navegador padrão
```powershell
Start-Process "c:\Users\bruno\Documents\Projects\html\prisma\dashboard.html"
```

#### Abrir profile com username
```powershell
Start-Process "c:\Users\bruno\Documents\Projects\html\prisma\profile.html?username=carly"
```

#### Ver estrutura de arquivos
```powershell
tree /F /A
```

## ✅ Teste Rápido (2 minutos)

1. Abra `dashboard.html`
2. Veja se o Prisma effect aparece
3. Clique no ícone de Followers
4. Clique em "Seguir" em um usuário
5. Clique no card do usuário
6. Você deve abrir `profile.html?username=...`
7. Clique em "Seguir" no profile
8. Volte ao dashboard
9. O usuário deve estar em "Seguindo"

**Se todos esses passos funcionarem: ✅ REORGANIZAÇÃO FUNCIONANDO PERFEITAMENTE!**

## 🐛 Como Reportar Bugs

Se encontrar problemas:

1. Abra o Console (F12)
2. Copie qualquer erro
3. Anote o que você estava fazendo
4. Verifique se os arquivos CSS/JS estão carregando (Network tab)

## 📞 Suporte

Arquivos de documentação:
- `ESTRUTURA.md` - Documentação da estrutura
- `REORGANIZACAO-COMPLETA.md` - Detalhes da reorganização
- Este arquivo (`GUIA-TESTE.md`) - Guia de testes