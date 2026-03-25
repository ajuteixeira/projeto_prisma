// Followers/Following JavaScript

document.addEventListener('DOMContentLoaded', function() {
    // Tab switching
    const followersTabs = document.querySelectorAll('.followers-tab');
    const tabContents = document.querySelectorAll('.tab-content');

    followersTabs.forEach(tab => {
        tab.addEventListener('click', function() {
            const tabName = this.getAttribute('data-tab');
            
            // Remove active from all tabs
            followersTabs.forEach(t => t.classList.remove('active'));
            
            // Add active to clicked tab
            this.classList.add('active');
            
            // Hide all tab contents
            tabContents.forEach(content => content.classList.remove('active'));
            
            // Show selected tab content
            const targetContent = document.getElementById(tabName);
            if (targetContent) {
                targetContent.classList.add('active');
            }

            // Update page title based on tab
            const followersHeader = document.querySelector('.followers-header h1');
            if (followersHeader) {
                if (tabName === 'seguidores') {
                    // Contagem estática para seguidores (poderia vir do servidor)
                    followersHeader.textContent = 'Seguidores (12)';
                } else if (tabName === 'seguindo') {
                    // Calcular a contagem de seguindo a partir do localStorage
                    const storedFollowing = JSON.parse(localStorage.getItem('following') || '[]');
                    followersHeader.textContent = `Seguindo (${storedFollowing.length})`;
                } else if (tabName === 'pesquisar') {
                    followersHeader.textContent = 'Pesquisar Pessoas';
                }
            }
        });
    });

    // Inicializar a lista de 'following' a partir do DOM para garantir consistência
    // (caso o HTML já marque alguns botões como 'following').
    // Deduplicamos usernames porque os mesmos usuários podem aparecer em múltiplas abas.
    (function syncFollowingFromDOM() {
        const followingButtons = document.querySelectorAll('.btn-follow.following');
        const usernames = Array.from(followingButtons).map(btn => {
            const card = btn.closest('.follower-card');
            if (!card) return null;
            const usernameEl = card.querySelector('.follower-username');
            return usernameEl ? usernameEl.textContent.replace('@', '').toLowerCase() : null;
        }).filter(Boolean);

        // Deduplicar
        const uniqueUsernames = Array.from(new Set(usernames));

        // Gravamos o estado baseado no DOM (deduplicado)
        localStorage.setItem('following', JSON.stringify(uniqueUsernames));

        // Atualiza elemento #followingCount se existir
        const followingCountElement = document.getElementById('followingCount');
        if (followingCountElement) {
            followingCountElement.textContent = uniqueUsernames.length;
        }

        // Se a aba ativa for 'seguindo', atualiza o título com a contagem correta
        const activeTab = document.querySelector('.followers-tab.active');
        const followersHeader = document.querySelector('.followers-header h1');
        if (activeTab && activeTab.getAttribute('data-tab') === 'seguindo' && followersHeader) {
            followersHeader.textContent = `Seguindo (${uniqueUsernames.length})`;
        }
    })();

    // Open profile page when clicking on follower card
    document.addEventListener('click', function(e) {
        const followerCard = e.target.closest('.follower-card');
        
        // Se clicar no card mas não no botão de seguir
        if (followerCard && !e.target.classList.contains('btn-follow')) {
            const username = followerCard.querySelector('.follower-username').textContent.replace('@', '');
            window.location.href = `profile.html?user=${username}`;
            return;
        }
    });

    // Follow/Unfollow button functionality
    document.addEventListener('click', function(e) {
        if (e.target.classList.contains('btn-follow')) {
            e.stopPropagation(); // Previne a abertura do perfil

            const followerCard = e.target.closest('.follower-card');
            const username = followerCard.querySelector('.follower-username').textContent.replace('@', '').toLowerCase();

            // Gerenciar localStorage de following
            let following = JSON.parse(localStorage.getItem('following') || '[]');

            console.log('Dashboard - Toggle follow for:', username);
            console.log('Current following list:', following);

            if (e.target.classList.contains('following')) {
                // Deixar de seguir
                e.target.classList.remove('following');
                e.target.textContent = 'Seguir';

                // Remover do localStorage
                following = following.filter(user => user !== username);
                localStorage.setItem('following', JSON.stringify(following));

                console.log('Unfollowed. New list:', following);
            } else {
                // Seguir
                e.target.classList.add('following');
                e.target.textContent = '';

                // Adicionar ao localStorage
                if (!following.includes(username)) {
                    following.push(username);
                    localStorage.setItem('following', JSON.stringify(following));
                }

                console.log('Followed. New list:', following);
            }

            // Atualizar contador a partir da lista atualizada (sempre confiável)
            const followingCountElement = document.getElementById('followingCount');
            const currentCount = following.length;
            if (followingCountElement) {
                followingCountElement.textContent = currentCount;
            }

            // Atualizar título da aba "Seguindo" caso esteja ativa
            const followersHeader = document.querySelector('.followers-header h1');
            const activeTab = document.querySelector('.followers-tab.active');
            if (activeTab && activeTab.getAttribute('data-tab') === 'seguindo' && followersHeader) {
                followersHeader.textContent = `Seguindo (${currentCount})`;
            }
        }
    });

    // Search functionality
    const searchInput = document.querySelector('.search-input');
    if (searchInput) {
        searchInput.addEventListener('input', function(e) {
            const searchTerm = e.target.value.toLowerCase();
            const followerCards = document.querySelectorAll('#pesquisar .follower-card');
            
            followerCards.forEach(card => {
                const name = card.querySelector('.follower-name').textContent.toLowerCase();
                const username = card.querySelector('.follower-username').textContent.toLowerCase();
                
                if (name.includes(searchTerm) || username.includes(searchTerm)) {
                    card.style.display = 'block';
                } else {
                    card.style.display = 'none';
                }
            });
        });
    }
});
