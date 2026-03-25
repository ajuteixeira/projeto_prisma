# Prisma - Estrutura do Projeto

## 📁 Organização de Arquivos

```
prisma/
├── css/
│   ├── global.css          # Estilos globais (Prisma effects, background, fonts)
│   ├── components.css      # Componentes reutilizáveis (cards, badges, progress bars)
│   ├── dashboard.css       # Estilos específicos do dashboard (sidebar, pins)
│   ├── modals.css          # Modais e configurações
│   ├── followers.css       # Página de seguidores/seguindo
│   └── profile.css         # Página de perfil de visitante
│
├── js/
│   ├── global.js           # JavaScript global (Prisma effects, particles, animations)
│   ├── dashboard.js        # Lógica do dashboard (navegação, modais, settings)
│   ├── followers.js        # Lógica de followers/following (tabs, search, follow)
│   └── profile.js          # Lógica do perfil visitante (dados, follow button)
│
└── *.html                  # Páginas HTML

## 🎨 CSS - Estrutura por Arquivo

### `global.css` (Obrigatório em todas as páginas)
- Reset e fonte global (Inter)
- Efeito Prisma (light beams, particles, animations)
- Background escuro com overlay
- Scrollbar customizada
- Utilitários globais (gradient-text)

### `components.css` (Usado em dashboard e profile)
- Cards (shimmer effect, hover states)
- Profile cards e stat cards
- Progress bars
- Game thumbnails e badges
- Platform badges
- Table headers
- Online indicators

### `dashboard.css` (Apenas dashboard.html)
- Sidebar fixa (navegação)
- Main content com margem
- Page sections (show/hide)
- Trophy icons
- Pinned achievements grid
- Edit profile overlay

### `modals.css` (Apenas dashboard.html)
- Modal base styles
- Settings page styles
- Logout e delete account cards
- Botões de ação (logout, delete)

### `followers.css` (Apenas dashboard.html - seção followers)
- Followers page layout
- Tabs navigation
- Search box
- Followers grid
- Follower cards com hover
- Follow buttons com estados

### `profile.css` (Apenas profile.html)
- Botão de seguir discreto (pequeno)

## 📜 JavaScript - Estrutura por Arquivo

### `global.js` (Obrigatório em todas as páginas)
- `platformStats` - Configuração das plataformas
- `generatePrismaEffect()` - Gera feixes de luz
- `createPrismaParticles()` - Cria partículas flutuantes
- Animação de progress bars
- Smooth scroll

### `dashboard.js` (Apenas dashboard.html)
- Navegação entre páginas (sidebar)
- `openEditProfile()` / `closeEditProfile()`
- `openPinAchievements()` / `closePinAchievements()`
- `showLogoutModal()` / `confirmLogout()`
- `showDeleteConfirmModal()` / `processDelete()` / `confirmDelete()`

### `followers.js` (Apenas dashboard.html - seção followers)
- Tabs switching (seguidores, seguindo, pesquisar)
- Navegação para perfil ao clicar no card
- Follow/Unfollow com localStorage
- Atualização de contadores
- Search/filter de usuários

### `profile.js` (Apenas profile.html)
- `getProfileUsername()` - Pega username da URL
- `profilesData` - Map de dados dos perfis
- `updateProfileInfo()` - Atualiza informações do perfil
- `isFollowing()` - Verifica se está seguindo
- `updateFollowButton()` - Mostra/esconde botão
- Follow functionality com notificação

## 🔗 Como Usar em Cada Página

### Dashboard (dashboard.html)
```html
<head>
    <!-- Tailwind & Font Awesome -->
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    
    <!-- CSS -->
    <link rel="stylesheet" href="css/global.css">
    <link rel="stylesheet" href="css/components.css">
    <link rel="stylesheet" href="css/dashboard.css">
    <link rel="stylesheet" href="css/modals.css">
    <link rel="stylesheet" href="css/followers.css">
</head>
<body>
    <!-- Conteúdo -->
    
    <!-- JavaScript -->
    <script src="js/global.js"></script>
    <script src="js/dashboard.js"></script>
    <script src="js/followers.js"></script>
</body>
```

### Profile (profile.html)
```html
<head>
    <!-- Tailwind & Font Awesome -->
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    
    <!-- CSS -->
    <link rel="stylesheet" href="css/global.css">
    <link rel="stylesheet" href="css/components.css">
    <link rel="stylesheet" href="css/profile.css">
</head>
<body>
    <!-- Conteúdo -->
    
    <!-- JavaScript -->
    <script src="js/global.js"></script>
    <script src="js/profile.js"></script>
</body>
```

### Páginas de Login/Cadastro (index.html, register.html, etc)
```html
<head>
    <!-- Tailwind & Font Awesome -->
    <script src="https://cdn.tailwindcss.com"></script>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    
    <!-- CSS -->
    <link rel="stylesheet" href="css/global.css">
    <!-- CSS específico da página (se houver) -->
</head>
<body>
    <!-- Conteúdo -->
    
    <!-- JavaScript -->
    <script src="js/global.js"></script>
    <!-- JavaScript específico da página (se houver) -->
</body>
```

## 💾 Dados Persistidos (localStorage)

### `following` (Array de strings)
Armazena os usernames que o usuário está seguindo.
```javascript
localStorage.getItem('following') // ["cipher.pro", "nova.star", "code.mage"]
```

Usado em:
- `followers.js` - Gerencia follow/unfollow no dashboard
- `profile.js` - Verifica se está seguindo e esconde/mostra botão

## 🎯 Benefícios da Nova Estrutura

✅ **Modularização**: Cada arquivo tem uma responsabilidade específica
✅ **Reutilização**: CSS e JS global são importados onde necessário
✅ **Manutenção**: Fácil localizar e editar código
✅ **Performance**: Carrega apenas o necessário para cada página
✅ **Escalabilidade**: Fácil adicionar novas páginas/features
✅ **Organização**: Código limpo e bem estruturado

## 📝 Próximos Passos

Para aplicar essa estrutura aos arquivos HTML existentes, você precisa:

1. Remover CSS inline de cada HTML
2. Remover JavaScript inline de cada HTML
3. Adicionar os links para os arquivos CSS apropriados
4. Adicionar os scripts JS apropriados
5. Testar cada página para garantir funcionalidade
