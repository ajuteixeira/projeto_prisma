// Profile Page JavaScript

// Get profile username from URL parameter
function getProfileUsername() {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get('user') || 'carly';
}

// Profile data map
const profilesData = {
    'cipher.pro': { name: 'Cypher Blade', seed: 'Cypher', followers: 234, following: 189, borderColor: 'border-blue-400' },
    'shadow.caster': { name: 'MysticShadow', seed: 'Mystic', followers: 156, following: 98, borderColor: 'border-purple-400' },
    'nova.star': { name: 'Nova Burst', seed: 'Nova', followers: 445, following: 312, borderColor: 'border-pink-400' },
    'phoenix.ignite': { name: 'PyroPhoenix', seed: 'Pyro', followers: 567, following: 423, borderColor: 'border-red-400' },
    'star.chaser': { name: 'GalacticHunter', seed: 'Galactic', followers: 789, following: 654, borderColor: 'border-indigo-400' },
    'code.mage': { name: 'Tech Sorcerer', seed: 'Tech', followers: 892, following: 723, borderColor: 'border-green-400' },
    'ocean.song': { name: 'AquaDiva', seed: 'Aqua', followers: 345, following: 267, borderColor: 'border-cyan-400' },
    'dark.harvester': { name: 'GrimReaper', seed: 'Grim', followers: 678, following: 534, borderColor: 'border-gray-400' },
    '8bit.queen': { name: 'PixelPrincess', seed: 'Pixel', followers: 923, following: 812, borderColor: 'border-pink-400' },
    'shock.wave': { name: 'VoltageWarrior', seed: 'Voltage', followers: 456, following: 378, borderColor: 'border-yellow-400' },
    'blood.wing': { name: 'CrimsonValkyrie', seed: 'Crimson', followers: 734, following: 621, borderColor: 'border-red-400' },
    'time.bender': { name: 'ChronoSage', seed: 'Chrono', followers: 512, following: 445, borderColor: 'border-purple-400' },
    'shadow.stealth': { name: 'ShadowNinja', seed: 'Shadow', followers: 289, following: 201, borderColor: 'border-gray-400' },
    'frost.core': { name: 'FrostByte', seed: 'Frost', followers: 398, following: 312, borderColor: 'border-blue-400' },
    'thunder.bolt': { name: 'ThunderStrike', seed: 'Thunder', followers: 623, following: 534, borderColor: 'border-yellow-400' },
    'moon.shadow': { name: 'LunarEclipse', seed: 'Luna', followers: 445, following: 367, borderColor: 'border-purple-400' },
    'toxic.fang': { name: 'VenomViper', seed: 'Venom', followers: 534, following: 423, borderColor: 'border-green-400' },
    'fire.dash': { name: 'BlazeRunner', seed: 'Blaze', followers: 712, following: 589, borderColor: 'border-orange-400' },
    'neon.specter': { name: 'NeonGhost', seed: 'Neon', followers: 456, following: 378, borderColor: 'border-pink-400' },
    'storm.fury': { name: 'StormBreaker', seed: 'Storm', followers: 823, following: 701, borderColor: 'border-blue-400' },
    'carly': { name: 'Carly', seed: 'Carly', followers: 89, following: 23, borderColor: 'border-purple-400' }
};

// Update profile information based on username
function updateProfileInfo() {
    const username = getProfileUsername();
    const profileData = profilesData[username] || profilesData['carly'];
    
    // Update avatar
    const profileAvatar = document.getElementById('profileAvatar');
    if (profileAvatar) {
        profileAvatar.src = `https://api.dicebear.com/7.x/avataaars/svg?seed=${profileData.seed}&backgroundColor=c0aede`;
        profileAvatar.alt = profileData.name;
        profileAvatar.className = `w-20 h-20 rounded-full border-2 ${profileData.borderColor}`;
    }
    
    // Update username
    const profileUsername = document.getElementById('profileUsername');
    if (profileUsername) {
        profileUsername.textContent = `@${username}`;
    }
    
    // Update counters
    const followersCount = document.getElementById('followersCount');
    const followingCount = document.getElementById('followingCount');
    if (followersCount) followersCount.textContent = profileData.followers;
    if (followingCount) followingCount.textContent = profileData.following;
    
    // Update page title
    document.title = `@${username} - Perfil - Prisma`;
}

// Check if current user is following this profile
function isFollowing(username) {
    const following = JSON.parse(localStorage.getItem('following') || '[]');
    const normalizedUsername = username.toLowerCase().replace('@', '');
    console.log('Checking if following:', normalizedUsername, 'in', following);
    return following.includes(normalizedUsername);
}

// Update follow button state
function updateFollowButton() {
    const followBtn = document.getElementById('followBtn');
    const username = getProfileUsername();
    
    console.log('Updating follow button for user:', username);
    
    if (followBtn) {
        if (isFollowing(username)) {
            console.log('User is following, hiding button');
            // Se já está seguindo, esconde o botão
            followBtn.style.display = 'none';
        } else {
            console.log('User is NOT following, showing "Seguir" button');
            // Se não está seguindo, mostra o botão
            followBtn.style.display = 'inline-block';
            followBtn.innerHTML = '<i class="fas fa-user-plus"></i> Seguir';
        }
    }
}

// Follow/Unfollow functionality
document.addEventListener('DOMContentLoaded', function() {
    const followBtn = document.getElementById('followBtn');
    if (followBtn) {
        followBtn.addEventListener('click', function() {
            const username = getProfileUsername();
            const normalizedUsername = username.toLowerCase().replace('@', '');
            let following = JSON.parse(localStorage.getItem('following') || '[]');
            
            console.log('Current following list:', following);
            console.log('Following user:', normalizedUsername);
            
            // Seguir (botão só aparece quando NÃO está seguindo)
            if (!following.includes(normalizedUsername)) {
                following.push(normalizedUsername);
                localStorage.setItem('following', JSON.stringify(following));
            }
            
            // Esconder o botão após seguir
            this.style.display = 'none';
            
            console.log('Followed. New list:', following);
            
            // Mostrar notificação
            showNotification('Você agora está seguindo @' + normalizedUsername);
        });
    }
});

// Show notification
function showNotification(message) {
    const notification = document.createElement('div');
    notification.style.cssText = `
        position: fixed;
        top: 80px;
        right: 24px;
        background: rgba(30, 35, 45, 0.95);
        color: white;
        padding: 16px 24px;
        border-radius: 8px;
        border: 1px solid rgba(96, 165, 250, 0.3);
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.4);
        z-index: 1000;
        font-size: 14px;
        backdrop-filter: blur(10px);
        animation: slideIn 0.3s ease-out;
    `;
    notification.textContent = message;
    document.body.appendChild(notification);

    setTimeout(() => {
        notification.style.animation = 'slideOut 0.3s ease-out';
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

// Initialize profile on page load
window.addEventListener('load', () => {
    updateProfileInfo();
    updateFollowButton();
});

// Add animation styles for notifications
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from {
            transform: translateX(400px);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }
    @keyframes slideOut {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(400px);
            opacity: 0;
        }
    }
`;
document.head.appendChild(style);
