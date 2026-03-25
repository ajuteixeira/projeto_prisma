// Global Prisma JavaScript

// Platform trophy statistics (percentages)
// Total must equal 100%
// Percentages control the intensity/opacity of each light beam
const platformStats = {
    playstation: { percentage: 20, color: '#0070CC', name: 'PlayStation' },
    xbox: { percentage: 10, color: '#107C10', name: 'Xbox' },
    steam: { percentage: 60, color: '#66c0f4', name: 'Steam' },
    retroachievements: { percentage: 10, color: '#D4A017', name: 'RetroAchievements' }
};

// Generate dynamic prisma effect based on platform percentages
function generatePrismaEffect() {
    const beams = {
        'beam-playstation': platformStats.playstation,
        'beam-xbox': platformStats.xbox,
        'beam-steam': platformStats.steam,
        'beam-retro': platformStats.retroachievements
    };

    Object.entries(beams).forEach(([className, platform]) => {
        const beam = document.querySelector(`.${className}`);
        if (beam) {
            // Calculate opacity based on percentage (10% = 0.2, 60% = 0.6, etc)
            const baseOpacity = platform.percentage / 100;
            beam.style.opacity = baseOpacity;
        }
    });
}

// Create floating particles based on platform colors
function createPrismaParticles() {
    const prismaBackground = document.querySelector('.prisma-background');
    if (!prismaBackground) return;
    
    const platforms = Object.values(platformStats);
    
    // Create particles proportional to platform percentage
    platforms.forEach(platform => {
        const particleCount = Math.floor(platform.percentage / 5); // 60% = 12 particles, 10% = 2 particles
        
        for (let i = 0; i < particleCount; i++) {
            const particle = document.createElement('div');
            particle.className = 'prisma-particle';
            particle.style.backgroundColor = platform.color;
            particle.style.left = Math.random() * 100 + '%';
            particle.style.animationDuration = (Math.random() * 15 + 10) + 's';
            particle.style.animationDelay = Math.random() * 5 + 's';
            particle.style.boxShadow = `0 0 10px ${platform.color}`;
            
            prismaBackground.appendChild(particle);
        }
    });
}

// Initialize Prisma effects on page load
window.addEventListener('load', () => {
    generatePrismaEffect();
    createPrismaParticles();
});

// Animate progress bars on load
window.addEventListener('load', () => {
    const progressBars = document.querySelectorAll('.progress-fill');
    progressBars.forEach(bar => {
        const width = bar.style.width;
        bar.style.width = '0%';
        setTimeout(() => {
            bar.style.width = width;
        }, 100);
    });
});

// Add smooth scroll behavior
document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        });
    });
});
