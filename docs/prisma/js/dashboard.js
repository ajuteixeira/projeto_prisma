// Dashboard JavaScript

// Navigation system
document.addEventListener('DOMContentLoaded', function() {
    const sidebarIcons = document.querySelectorAll('.sidebar-icon');
    const pages = document.querySelectorAll('.page-section');

    sidebarIcons.forEach(icon => {
        icon.addEventListener('click', function() {
            const targetPage = this.getAttribute('data-page');
            
            // Remove active from all icons
            sidebarIcons.forEach(i => i.classList.remove('active'));
            
            // Add active to clicked icon
            this.classList.add('active');
            
            // Hide all pages
            pages.forEach(page => page.classList.remove('active'));
            
            // Show target page
            const target = document.querySelector(`.${targetPage}`);
            if (target) {
                target.classList.add('active');
            }
        });
    });

    // Achievement click handlers
    const achievements = document.querySelectorAll('.pinned-achievement');
    achievements.forEach(achievement => {
        achievement.addEventListener('click', function() {
            const data = JSON.parse(this.getAttribute('data-achievement'));
            openAchievementModal(data);
        });
    });

    // Open pinned achievements manager
    const openPinBtn = document.getElementById('openPinModal');
    if (openPinBtn) {
        openPinBtn.addEventListener('click', function(e) {
            e.stopPropagation();
            openPinAchievements();
        });
    }

    // Profile photo change handler
    const profilePhotoInput = document.getElementById('profilePhotoInput');
    if (profilePhotoInput) {
        profilePhotoInput.addEventListener('change', function(e) {
            const file = e.target.files[0];
            if (file) {
                // Check file size (2MB max)
                if (file.size > 2 * 1024 * 1024) {
                    alert('A imagem deve ter no máximo 2MB.');
                    return;
                }

                // Check file type
                if (!file.type.match('image/(jpeg|png|gif)')) {
                    alert('Apenas JPG, PNG ou GIF são aceitos.');
                    return;
                }

                // Preview the image
                const reader = new FileReader();
                reader.onload = function(e) {
                    const editAvatar = document.getElementById('editProfileAvatar');
                    const profileAvatar = document.getElementById('profileAvatar');
                    if (editAvatar) {
                        editAvatar.src = e.target.result;
                    }
                    if (profileAvatar) {
                        profileAvatar.src = e.target.result;
                    }
                };
                reader.readAsDataURL(file);
            }
        });
    }
});

// Global focus handler: when any input inside a modal receives focus, ensure bottom nav hides
document.addEventListener('focusin', function(e) {
    try {
        const target = e.target;
        if (!target) return;
        // if focused element is inside a modal overlay (common pattern: fixed inset-0)
        const modalOverlay = target.closest('.fixed.inset-0');
        if (modalOverlay && window.getComputedStyle(modalOverlay).display !== 'none') {
            const sidebar = document.querySelector('.sidebar');
            if (sidebar) sidebar.classList.add('modal-open');
        }
    } catch (err) {
        // swallow
    }
});

// Edit Profile Modal
function openEditProfile() {
    const modal = document.getElementById('editProfileModal');
    if (modal) {
        // Populate with current values
        const currentName = document.getElementById('profileName').textContent;
        const editNickname = document.getElementById('editNickname');
        if (editNickname) {
            // Remove leading @ and any whitespace so the input only contains the nickname
            editNickname.value = currentName.replace(/^@\s*/, '');
        }
        modal.style.display = 'flex';
        const sidebar = document.querySelector('.sidebar');
        if (sidebar) sidebar.classList.add('modal-open');
    }
}

function closeEditProfile() {
    const modal = document.getElementById('editProfileModal');
    if (modal) {
        modal.style.display = 'none';
        const sidebar = document.querySelector('.sidebar');
        if (sidebar) sidebar.classList.remove('modal-open');
    }
}

function saveProfile() {
    const fullName = document.getElementById('editFullName').value;
    let nickname = document.getElementById('editNickname').value;
    if (!nickname) nickname = '';
    // Normalize: remove any leading @ or spaces, enforce allowed chars and lowercase
    nickname = nickname.replace(/^@+/, '').trim().toLowerCase();
    // Keep only letters, numbers and underscore
    nickname = nickname.replace(/[^a-z0-9_]/g, '');
    
    // Update profile display
    const profileName = document.getElementById('profileName');
    if (profileName) {
        // Display with @ prefix
        profileName.textContent = nickname ? (`@${nickname}`) : fullName;
    }
    
    closeEditProfile();
}

// Pin Achievements Modal
function openPinAchievements() {
    const modal = document.getElementById('pinAchievementsModal');
    console.log('[debug] openPinAchievements called');
    if (modal) {
        // Populate list of achievements
        populatePinModal();
        modal.style.display = 'flex';
        const sidebar = document.querySelector('.sidebar');
        if (sidebar) sidebar.classList.add('modal-open');
    }
}

function closePinAchievements() {
    const modal = document.getElementById('pinAchievementsModal');
    if (modal) {
        modal.style.display = 'none';
        const sidebar = document.querySelector('.sidebar');
        if (sidebar) sidebar.classList.remove('modal-open');
    }
}

// Populate the pin modal list from available achievements on the page
function populatePinModal() {
    const pinList = document.getElementById('pinList');
    const pinSearch = document.getElementById('pinSearch');
    if (!pinList) return;

    // Gather all achievements defined on the page (data-achievement attributes)
    const achievementEls = Array.from(document.querySelectorAll('[data-achievement]'));

    // Map to unique achievements by name
    const achievementsMap = new Map();
    achievementEls.forEach(el => {
        try {
            const data = JSON.parse(el.getAttribute('data-achievement'));
            if (data && data.name) {
                achievementsMap.set(data.name, data);
            }
        } catch (err) {
            // ignore parse errors
        }
    });

    const achievements = Array.from(achievementsMap.values());

    // Get currently pinned names from localStorage (or use existing pinnedGrid)
    let pinned = JSON.parse(localStorage.getItem('pinnedAchievements') || 'null');
    if (!Array.isArray(pinned)) {
        // Fallback: read from initial #pinnedGrid
        const initial = document.querySelectorAll('#pinnedGrid .pinned-achievement');
        pinned = Array.from(initial).map(el => {
            try { return JSON.parse(el.getAttribute('data-achievement')).name; } catch(e){return null}
        }).filter(Boolean);
    }

    // Normalize previously-stored values that may have been HTML-escaped
    const decodeHtml = (s) => String(s).replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&quot;/g,'"').replace(/&#39;/g,"'");
    if (Array.isArray(pinned)) pinned = pinned.map(p => decodeHtml(p));

    // Build HTML list
    pinList.innerHTML = '';
    achievements.forEach(item => {
        const idSafe = `pin_${item.name.replace(/[^a-z0-9]/gi,'_')}`;
        const node = document.createElement('div');
        node.className = 'flex items-center gap-3 p-3 bg-gray-800/50 rounded-lg';

        // Checkbox (store raw name in dataset.name to avoid storing HTML-escaped values)
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.id = idSafe;
        checkbox.className = 'pin-checkbox';
        checkbox.dataset.name = item.name; // raw name
        if (Array.isArray(pinned) && pinned.includes(item.name)) checkbox.checked = true;

        const iconDiv = document.createElement('div');
        iconDiv.className = 'w-10 h-10 bg-gray-700 rounded flex items-center justify-center text-lg';
        iconDiv.textContent = item.icon || '🏆';

        const contentDiv = document.createElement('div');
        contentDiv.className = 'flex-1';
        const title = document.createElement('div');
        title.className = 'text-white font-semibold';
        title.innerHTML = escapeHtml(item.name);
        const subtitle = document.createElement('div');
        subtitle.className = 'text-gray-400 text-sm';
        subtitle.innerHTML = escapeHtml(item.description || item.game || '');

        contentDiv.appendChild(title);
        contentDiv.appendChild(subtitle);

        node.appendChild(checkbox);
        node.appendChild(iconDiv);
        node.appendChild(contentDiv);
        pinList.appendChild(node);
    });

    // Limit: no more than 4 pinned items allowed.
    const limit = 4;
    const messageEl = document.getElementById('pinLimitMessage');

    // If localStorage contains more than allowed, clamp and persist
    if (Array.isArray(pinned) && pinned.length > limit) {
        pinned = pinned.slice(0, limit);
        localStorage.setItem('pinnedAchievements', JSON.stringify(pinned));
    }

    // Add change handlers to enforce the limit dynamically
    const checkboxes = Array.from(document.querySelectorAll('#pinList .pin-checkbox'));
    checkboxes.forEach(cb => {
        cb.addEventListener('change', function(e) {
            const currentlyChecked = checkboxes.filter(x => x.checked).length;
            if (currentlyChecked > limit) {
                // revert this change
                this.checked = false;
                // show message to the user
                if (messageEl) {
                    messageEl.textContent = `Você pode fixar no máximo ${limit} conquistas. Desmarque outra para fixar mais.`;
                    messageEl.style.display = 'block';
                    // hide after 3s
                    setTimeout(() => { messageEl.style.display = 'none'; }, 3000);
                } else {
                    alert(`Você pode fixar no máximo ${limit} conquistas. Desmarque outra para fixar mais.`);
                }
            }
        });
    });

    // Search handler
    if (pinSearch) {
        pinSearch.value = '';
        pinSearch.oninput = function() {
            const term = this.value.toLowerCase();
            Array.from(pinList.children).forEach(child => {
                const text = child.textContent.toLowerCase();
                child.style.display = text.includes(term) ? '' : 'none';
            });
        };
    }

    // Wire actions for cancel/save
    const btnCancel = document.getElementById('pinCancel');
    const btnSave = document.getElementById('pinSave');
    if (btnCancel) btnCancel.onclick = closePinAchievements;
    if (btnSave) btnSave.onclick = savePinnedFromModal;
}

function savePinnedFromModal() {
    const checkboxes = Array.from(document.querySelectorAll('#pinList .pin-checkbox'));
    // Read names robustly (dataset preferred)
    const selectedNames = checkboxes.filter(cb => cb.checked).map(cb => (cb.dataset && cb.dataset.name) || cb.getAttribute('data-name') || cb.value).filter(Boolean);

    // Enforce max 4 just in case (defensive)
    const limit = 4;
    let toSave = selectedNames;
    if (toSave.length > limit) {
        toSave = toSave.slice(0, limit);
    }

    // Persist to localStorage
    localStorage.setItem('pinnedAchievements', JSON.stringify(toSave));

    // Immediately read back the saved value and populate the pinnedGrid from that authoritative source
    try {
        const saved = JSON.parse(localStorage.getItem('pinnedAchievements') || 'null');
        const all = Array.from(document.querySelectorAll('[data-achievement]'));
        const pinnedGrid = document.getElementById('pinnedGrid');
        if (Array.isArray(saved) && pinnedGrid) {
            pinnedGrid.innerHTML = '';
            saved.forEach(name => {
                const match = all.find(el => {
                    try { const d = JSON.parse(el.getAttribute('data-achievement')); return d && d.name === name; } catch(e){return false}
                });
                if (match) {
                    const data = match.getAttribute('data-achievement');
                    const div = document.createElement('div');
                    div.className = 'pinned-achievement';
                    div.setAttribute('data-achievement', data);
                    const parsed = JSON.parse(data);
                    div.innerHTML = `
                        <div class="achievement-icon">${escapeHtml(parsed.icon || '🏆')}</div>
                        <div class="achievement-name">${escapeHtml(parsed.name)}</div>
                    `;
                    pinnedGrid.appendChild(div);
                }
            });

            // Re-bind achievement click handlers so the cloned nodes open the modal
            const achievements = document.querySelectorAll('.pinned-achievement');
            achievements.forEach(achievement => {
                achievement.addEventListener('click', function() {
                    const data = JSON.parse(this.getAttribute('data-achievement'));
                    openAchievementModal(data);
                });
            });
        }
    } catch (e) {
        // ignore
    }

    closePinAchievements();
}

function escapeHtml(str){
    return String(str).replace(/[&"'<>]/g, function(m){return {'&':'&amp;','"':'&quot;',"'":"&#39;",'<':'&lt;','>':'&gt;'}[m];});
}

// On load, if localStorage contains pinnedAchievements, populate the pinnedGrid
document.addEventListener('DOMContentLoaded', function() {
    try {
        const saved = JSON.parse(localStorage.getItem('pinnedAchievements') || 'null');
        if (Array.isArray(saved)) {
            const all = Array.from(document.querySelectorAll('[data-achievement]'));
            const pinnedGrid = document.getElementById('pinnedGrid');
            if (pinnedGrid) {
                pinnedGrid.innerHTML = '';
                const decodeHtml = (s) => String(s).replace(/&amp;/g,'&').replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&quot;/g,'"').replace(/&#39;/g,"'");
                const normalized = saved.map(s => decodeHtml(s));
                normalized.forEach(name => {
                    const match = all.find(el => {
                        try { const d = JSON.parse(el.getAttribute('data-achievement')); return d && d.name === name; } catch(e){return false}
                    });
                    if (match) {
                        const data = match.getAttribute('data-achievement');
                        const div = document.createElement('div');
                        div.className = 'pinned-achievement';
                        div.setAttribute('data-achievement', data);
                        const parsed = JSON.parse(data);
                        div.innerHTML = `
                            <div class="achievement-icon">${escapeHtml(parsed.icon || '🏆')}</div>
                            <div class="achievement-name">${escapeHtml(parsed.name)}</div>
                        `;
                        pinnedGrid.appendChild(div);
                    }
                });

                // re-bind click handlers
                const achievements = document.querySelectorAll('.pinned-achievement');
                achievements.forEach(achievement => {
                    achievement.addEventListener('click', function() {
                        const data = JSON.parse(this.getAttribute('data-achievement'));
                        openAchievementModal(data);
                    });
                });
            }
        }
    } catch(e) {
        // ignore
    }
});

// Settings - Logout
document.addEventListener('click', function(e) {
    if (e.target.classList.contains('btn-logout')) {
        showLogoutModal();
    }
});

function showLogoutModal() {
    const modal = document.getElementById('logoutModal');
    if (modal) {
        modal.style.display = 'flex';
        const sidebar = document.querySelector('.sidebar');
        if (sidebar) sidebar.classList.add('modal-open');

        // (no input focus needed for logout modal)
    }
}

function confirmLogout() {
    window.location.href = 'index.html';
}

// Settings - Delete Account
document.addEventListener('click', function(e) {
    if (e.target.classList.contains('btn-delete')) {
        showDeleteConfirmModal();
    }
});

function showDeleteConfirmModal() {
    const modal = document.getElementById('deleteConfirmModal');
    if (modal) {
        console.log('[modal-debug] showDeleteConfirmModal() called');
        modal.style.display = 'flex';
        // mark overlay as compact so actions stay closer to content while modal is open
        modal.classList.add('actions-compact');
        const sidebar = document.querySelector('.sidebar');
        if (sidebar) sidebar.classList.add('modal-open');
        // small delay then ensure actions visible and focus input (ux for mobile)
        setTimeout(() => {
            try {
                const actions = modal.querySelector('.modal-actions');
                const input = document.getElementById('deleteConfirmInput');
                // Do not scroll or reposition actions on open — keep actions fixed inside modal.
                // focus the input so the keyboard appears and we can rely on focus handlers
                if (input) {
                    input.focus({ preventScroll: true });
                    console.log('[modal-debug] focused delete input after open');
                }
            } catch(e) { /* swallow on older browsers */ }
        }, 220);
    }
}

function closeDeleteConfirm() {
    const modal = document.getElementById('deleteConfirmModal');
    const input = document.getElementById('deleteConfirmInput');
    if (modal) {
        console.log('[modal-debug] closeDeleteConfirm() called');
        modal.style.display = 'none';
        // ensure any temporary classes are removed when modal closes
        modal.classList.remove('actions-compact');
        // no actions-shifted anymore — ensure pinned/fixed removed elsewhere
        const sidebar = document.querySelector('.sidebar');
        if (sidebar) sidebar.classList.remove('modal-open');
    }
    if (input) {
        input.value = '';
    }
}

function processDelete() {
    const input = document.getElementById('deleteConfirmInput');
    if (input && input.value === 'EXCLUIR') {
        closeDeleteConfirm();
        showDeleteSuccessModal();
    } else {
        alert('Por favor, digite "EXCLUIR" para confirmar.');
    }
}

function showDeleteSuccessModal() {
    const modal = document.getElementById('deleteModal');
    if (modal) {
        modal.style.display = 'flex';
        const sidebar = document.querySelector('.sidebar');
        if (sidebar) sidebar.classList.add('modal-open');
    }
}

function confirmDelete() {
    window.location.href = 'index.html';
}

// Achievement Modal
function openAchievementModal(data) {
    const modal = document.getElementById('achievementModal');
    if (!modal) return;

    // Populate modal with achievement data
    document.getElementById('modalAchievementName').textContent = data.name;
    document.getElementById('modalAchievementGame').textContent = data.game;
    document.getElementById('modalAchievementIcon').textContent = data.icon;
    document.getElementById('modalAchievementDescription').textContent = data.description;
    document.getElementById('modalAchievementPercentage').textContent = data.percentage + '%';
    document.getElementById('modalAchievementImage').src = data.image;
    
    // Format rarity
    const rarityMap = {
        'common': 'Comum',
        'uncommon': 'Incomum',
        'rare': 'Raro',
        'epic': 'Épico',
        'legendary': 'Lendário'
    };
    document.getElementById('modalAchievementRarity').textContent = rarityMap[data.rarity] || data.rarity;

    modal.style.display = 'flex';
    const sidebar = document.querySelector('.sidebar');
    if (sidebar) sidebar.classList.add('modal-open');
}

function closeAchievementModal() {
    const modal = document.getElementById('achievementModal');
    if (modal) {
        modal.style.display = 'none';
        const sidebar = document.querySelector('.sidebar');
        if (sidebar) sidebar.classList.remove('modal-open');
    }
}

// UX fallback: when the delete confirm input is focused (mobile keyboard open), ensure actions are visible
document.addEventListener('DOMContentLoaded', function() {
    const input = document.getElementById('deleteConfirmInput');
    if (input) {
        input.addEventListener('focus', function() {
            console.log('[modal-debug] deleteConfirmInput focused (innerHeight=', window.innerHeight, ')');
            // ensure bottom nav is hidden if present
            const sidebar = document.querySelector('.sidebar');
            if (sidebar) sidebar.classList.add('modal-open');

            // Keep actions visually stable. Only ensure modal state and don't scroll
            // or reposition elements when the input receives focus.
            const modal = document.getElementById('deleteConfirmModal');
            if (!modal) return;
            // no-op: intentionally do not scroll or toggle classes.
        });

                // NOTE: we don't remove modal-open on blur because the modal may still be open;
        // the modal closing functions are responsible for removing the class.
                // ensure pinned state is removed on blur
                input.addEventListener('blur', function() {
                    try {
                        const modal = document.getElementById('deleteConfirmModal');
                        const actions = modal && modal.querySelector('.modal-actions');
                        if (actions) {
                                // on blur: do not modify actions placement — leave the UI stable
                                console.log('[modal-debug] blur: no change to actions placement');
                            }
                    } catch(e) {}
                });

                // visualViewport detection — some mobile browsers adjust visual viewport when keyboard appears
                if (window.visualViewport) {
                    // Removed visualViewport-driven repositioning logic intentionally —
                    // the action buttons are kept stationary inside the modal at all times.
                }
    }
});

// Fallback: event delegation for abrir o modal de "Gerenciar" caso a ligação direta não tenha sido feita
document.addEventListener('click', function(e) {
    const targetBtn = e.target.closest('#openPinModal');
    if (targetBtn) {
        e.stopPropagation();
        console.log('[debug] #openPinModal clicked via delegation');
        if (typeof openPinAchievements === 'function') {
            openPinAchievements();
        } else {
            console.warn('[debug] openPinAchievements is not defined');
        }
    }
});
