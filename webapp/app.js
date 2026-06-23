/* ==========================================
   TechWing Attendance - Main Application
   Matches Flutter App Structure 100%
   ========================================== */

// App State - Matching Flutter providers
const AppState = {
    isLoggedIn: false,
    currentUser: null,
    userRole: 'user', // 'admin' or 'user'
    currentScreen: 'home-screen',
    currentTab: 0, // 0: Home/Scanner, 1: Dashboard, 2: Settings
    activeClass: null,
    sessionType: 'morning',
    sessionDate: new Date().toISOString().split('T')[0],
    attendanceRecords: [],
    recentScans: [],
    syncPending: 0,
    interviewRating: 0,
    navigationStack: [] // NEW: Track navigation history for back button
};

// Wait for DOM to load
document.addEventListener('DOMContentLoaded', function () {
    initializeApp();
});

// Initialize Application
function initializeApp() {
    console.log('🚀 TechWing Attendance App Initializing...');

    // Dismiss loading screen after animation completes
    const loadingScreen = document.getElementById('loading-screen');
    if (loadingScreen) {
        setTimeout(() => {
            loadingScreen.classList.add('fade-out');
            setTimeout(() => {
                loadingScreen.style.display = 'none';
            }, 800); // Match the CSS transition duration
        }, 3200); // Wait for the progress bar animation (3s) + small buffer
    }

    // Initialize all event listeners first
    initLoginEvents();
    initBottomNavigation();
    initHomeScreenEvents();
    initScannerScreenEvents();
    initSessionSetupEvents();
    initAttendanceCheckEvents();
    initClassDetailsEvents();
    initStudentSearchEvents();
    initMockInterviewEvents();
    initDashboardEvents();
    initDashboardClassDropdown();
    initSettingsEvents();
    initBatchOverviewEvents();
    initManagementEvents(); // Initialize Admin/Management events

    // Check for Firebase auth state
    if (typeof FirebaseService !== 'undefined') {
        FirebaseService.auth.onAuthStateChanged((firebaseUser) => {
            if (firebaseUser) {
                // User is signed in with Firebase
                const savedUser = localStorage.getItem('techwing_user');
                if (savedUser) {
                    try {
                        const user = JSON.parse(savedUser);
                        loginSuccess(user);
                    } catch (e) {
                        console.log('No valid saved session');
                    }
                }
            } else {
                console.log('No Firebase user signed in');
            }
        });
    } else {
        // Fallback to localStorage check if Firebase not loaded
        const savedUser = localStorage.getItem('techwing_user');
        if (savedUser) {
            try {
                const user = JSON.parse(savedUser);
                loginSuccess(user);
            } catch (e) {
                console.log('No valid saved session');
            }
        }
    }

    console.log('✅ App initialized successfully');
}

// ==========================================
// LOGIN
// ==========================================
function initLoginEvents() {
    const loginForm = document.getElementById('login-form');
    const syncBtn = document.getElementById('sync-credentials-btn');

    loginForm.addEventListener('submit', function (e) {
        e.preventDefault();
        handleLogin();
    });

    syncBtn.addEventListener('click', function () {
        showToast('Credentials synced successfully!', 'success');
    });

    // Role Selector Toggle
    const roleAdminBtn = document.getElementById('role-admin-btn');
    const roleUserBtn = document.getElementById('role-user-btn');
    const loginRoleInput = document.getElementById('login-role');

    if (roleAdminBtn && roleUserBtn) {
        roleAdminBtn.addEventListener('click', function () {
            roleAdminBtn.classList.add('active');
            roleUserBtn.classList.remove('active');
            loginRoleInput.value = 'admin';
        });

        roleUserBtn.addEventListener('click', function () {
            roleUserBtn.classList.add('active');
            roleAdminBtn.classList.remove('active');
            loginRoleInput.value = 'user';
        });
    }

    // Demo Login Bypass - logs in as admin
    const demoBtn = document.getElementById('demo-login-btn');
    if (demoBtn) {
        demoBtn.addEventListener('click', function () {
            const demoUser = {
                name: 'Demo Admin',
                username: 'demo',
                email: 'demo@techwing.com',
                role: 'admin',
                uid: 'demo-123'
            };
            localStorage.setItem('techwing_user', JSON.stringify(demoUser));
            loginSuccess(demoUser);
        });
    }
}

async function handleLogin() {
    const username = document.getElementById('username').value.trim();
    const password = document.getElementById('password').value;
    const selectedRole = document.getElementById('login-role').value; // 'admin' or 'user'
    const loginBtn = document.getElementById('login-btn');
    const errorDiv = document.getElementById('login-error');

    if (!username || !password) {
        errorDiv.textContent = 'Please enter username and password';
        errorDiv.classList.remove('hidden');
        return;
    }

    loginBtn.querySelector('.btn-text').classList.add('hidden');
    loginBtn.querySelector('.btn-loader').classList.remove('hidden');
    loginBtn.disabled = true;
    errorDiv.classList.add('hidden');

    try {
        // Use Firebase auth with @gmail.com auto-append
        const user = await FirebaseService.signInWithUsername(username, password);

        // Determine role
        let actualRole = 'user';

        if (selectedRole === 'admin') {
            // Check if user is in hardcoded admin list
            const isHardcoded = FirebaseService.isHardcodedAdmin(username);

            if (isHardcoded) {
                actualRole = 'admin';
                // Ensure admin role is saved in Firebase for this user
                try {
                    await FirebaseService.setUserRole(user.uid, 'admin');
                } catch (e) {
                    console.log('Could not auto-set admin role in DB (may need initial setup)');
                }
            } else {
                // Check Firebase /roles node
                const dbRole = await FirebaseService.fetchUserRole(user.uid);
                if (dbRole === 'admin') {
                    actualRole = 'admin';
                } else {
                    // Not an admin - deny access
                    errorDiv.textContent = 'You don\'t have admin access. Please login as User.';
                    errorDiv.classList.remove('hidden');
                    loginBtn.querySelector('.btn-text').classList.remove('hidden');
                    loginBtn.querySelector('.btn-loader').classList.add('hidden');
                    loginBtn.disabled = false;
                    return;
                }
            }
        }

        const userData = {
            name: username.charAt(0).toUpperCase() + username.slice(1),
            username: username,
            email: user.email,
            role: actualRole,
            uid: user.uid
        };

        localStorage.setItem('techwing_user', JSON.stringify(userData));
        loginSuccess(userData);
    } catch (error) {
        console.error('Login error:', error);
        console.error('Error code:', error.code);
        console.error('Error message:', error.message);

        let errorMessage = 'Login failed. Please try again.';

        if (error.code === 'auth/wrong-password') {
            errorMessage = 'Incorrect password';
        } else if (error.code === 'auth/too-many-requests') {
            errorMessage = 'Too many attempts. Try again later.';
        } else if (error.code === 'auth/weak-password') {
            errorMessage = 'Password must be at least 6 characters';
        } else if (error.code === 'auth/operation-not-allowed') {
            errorMessage = 'Email/Password auth not enabled in Firebase!';
        } else if (error.code === 'auth/invalid-api-key') {
            errorMessage = 'Invalid Firebase API key';
        } else if (error.code) {
            // Show the actual error code for debugging
            errorMessage = `Error: ${error.code}`;
        }

        errorDiv.textContent = errorMessage;
        errorDiv.classList.remove('hidden');
        loginBtn.querySelector('.btn-text').classList.remove('hidden');
        loginBtn.querySelector('.btn-loader').classList.add('hidden');
        loginBtn.disabled = false;
    }
}

function loginSuccess(user) {
    AppState.isLoggedIn = true;
    AppState.currentUser = user;
    AppState.userRole = user.role || 'user';

    // Update greeting - Matches Flutter "Hi, [Name] garu"
    document.getElementById('user-display-name').textContent = user.name;
    document.getElementById('profile-name').textContent = user.name;
    document.getElementById('profile-role').textContent = AppState.userRole === 'admin' ? 'Admin' : 'User';

    // Hide login, show main app
    document.getElementById('login-screen').classList.remove('active');
    document.getElementById('main-app').classList.remove('hidden');

    // Apply role-based restrictions
    applyRoleRestrictions();

    // Initialize data
    initializeAppData();

    // Show home screen
    navigateToTab(0);
}

/**
 * Apply role-based restrictions to the UI
 * Hides admin-only elements for regular users
 */
function applyRoleRestrictions() {
    const isAdmin = AppState.userRole === 'admin';

    // Show/hide all elements with [data-admin-only] attribute
    document.querySelectorAll('[data-admin-only]').forEach(el => {
        el.style.display = isAdmin ? '' : 'none';
    });

    // Update Settings/Profile nav tab
    const navSettingsIcon = document.getElementById('nav-settings-icon');
    const navSettingsLabel = document.getElementById('nav-settings-label');

    if (navSettingsIcon && navSettingsLabel) {
        if (isAdmin) {
            navSettingsIcon.className = 'fas fa-cog';
            navSettingsLabel.textContent = 'Settings';
        } else {
            navSettingsIcon.className = 'fas fa-user-circle';
            navSettingsLabel.textContent = 'Profile';
        }
    }

    console.log(`🔒 Role restrictions applied: ${isAdmin ? 'ADMIN' : 'USER'}`);
}

async function initializeAppData() {
    updateDashboardDate();

    // Load data from Firebase if available
    if (typeof FirebaseService !== 'undefined') {
        try {
            console.log('📡 Loading data from Firebase...');

            // Fetch batches
            const batches = await FirebaseService.fetchBatches();
            AppState.batches = batches || {};
            console.log('✅ Loaded batches:', Object.keys(AppState.batches));

            // Convert batches to classes format for dropdown compatibility
            const batchKeys = Object.keys(AppState.batches);
            if (batchKeys.length > 0) {
                // For each batch, fetch students
                for (const batchId of batchKeys) {
                    const students = await FirebaseService.fetchStudents(batchId);
                    AppState.batches[batchId].students = students || {};
                    console.log(`✅ Loaded ${Object.keys(students || {}).length} students for ${batchId}`);
                }

                // Create classes array for compatibility with existing dropdowns
                AppState.firebaseClasses = batchKeys.map(batchId => ({
                    id: batchId,
                    className: AppState.batches[batchId].name || batchId,
                    classCode: batchId,
                    students: Object.values(AppState.batches[batchId].students || {})
                }));

                // Refresh UI with new data
                renderClassList();
                if (AppState.currentScreen === 'batch-overview-screen') {
                    renderBatchOverview();
                }

                // Default: Do NOT select a batch automatically on load
                // The user must explicitly select a batch
                // if (AppState.firebaseClasses.length > 0) {
                //    selectFirebaseClass(AppState.firebaseClasses[0].id);
                // }
            }

            // Populate dropdowns with Firebase data
            populateFirebaseDropdowns();

            // REMOVED: showToast('Data loaded from Firebase', 'success'); 

            // Hide Ultimate Loading Screen
            const loader = document.getElementById('loading-screen');
            if (loader) {
                setTimeout(() => {
                    loader.classList.add('fade-out');
                }, 1500); // Ensure users see the cool animation for at least 1.5s
            }

        } catch (error) {
            console.error('❌ Error loading Firebase data:', error);
            showToast('Using offline data', 'warning');

            // Hide Loader on error too
            const loader = document.getElementById('loading-screen');
            if (loader) loader.classList.add('fade-out');

            // Fallback to mock data
            populateAllDropdowns();
            if (mockData.classes.length > 0) {
                selectClass(mockData.classes[0].id);
            }
        }
    } else {
        // Use mock data as fallback
        populateAllDropdowns();

        // Hide Loader for offline mode
        const loader = document.getElementById('loading-screen');
        if (loader) {
            setTimeout(() => {
                loader.classList.add('fade-out');
            }, 1000);
        }

        if (mockData.classes.length > 0) {
            selectClass(mockData.classes[0].id);
        }
    }
}

function populateAllDropdowns() {
    // Initialize Session Class Dropdown
    initSessionClassDropdown();

    // Initialize Attendance Check Class Dropdown
    initCheckClassDropdown();

    // Initialize Interview Class Dropdown
    initInterviewClassDropdown();

    // Initialize Interview Student Dropdown (empty initially)
    initInterviewStudentDropdown([]);

    // Initialize Batch Dropdown
    initBatchDropdown();

    // Initialize Dashboard Batch Dropdown (with mock data)
    const classes = AppState.firebaseClasses || mockData.classes;
    console.log('📋 Initializing Dashboard Dropdown with', classes.length, 'classes');
    const dashOptions = [
        { value: '', label: 'Select a batch...' },
        ...classes.map(c => ({ value: c.id, label: `${c.className} (${c.classCode})` }))
    ];
    console.log('📋 Dashboard options:', dashOptions);
    initCustomDropdown('dashboard-class-dropdown-wrapper', 'dashboard-class-menu-portal', dashOptions, (value) => {
        console.log('📋 Dashboard dropdown selected:', value);
        if (value) {
            if (AppState.firebaseClasses) {
                selectFirebaseClass(value);
            } else {
                selectClass(value);
            }
            updateDashboard();
        }
    });

    // Initialize Scanner Batch Dropdown (with mock data)
    console.log('📋 Initializing Scanner Dropdown');
    const scannerOptions = [
        { value: '', label: 'Select a batch...' },
        ...classes.map(c => ({ value: c.id, label: c.className }))
    ];
    initCustomDropdown('scanner-batch-dropdown-wrapper', 'scanner-batch-menu-portal', scannerOptions, (value) => {
        console.log('📋 Scanner dropdown selected:', value);
        if (value) {
            if (AppState.firebaseClasses) {
                selectFirebaseClass(value);
            } else {
                selectClass(value);
            }
            showToast(`Scanning for: ${classes.find(c => c.id === value)?.className || value}`, 'info');
        }
    });
}

// ==========================================
// FIREBASE DATA FUNCTIONS
// ==========================================

/**
 * Populate dropdowns with Firebase data
 */
function populateFirebaseDropdowns() {
    const classes = AppState.firebaseClasses || [];

    // Session Class Dropdown
    const sessionOptions = [
        { value: '', label: 'Select a batch...' },
        ...classes.map(c => ({ value: c.id, label: c.className }))
    ];
    initCustomDropdown('session-class-dropdown-wrapper', 'session-class-menu-portal', sessionOptions, (value) => {
        if (value) selectFirebaseClass(value);
    });

    // Check Class Dropdown
    const checkOptions = [
        { value: '', label: 'Select a batch...' },
        ...classes.map(c => ({ value: c.id, label: c.className }))
    ];
    initCustomDropdown('check-class-dropdown-wrapper', 'check-class-menu-portal', checkOptions, (value) => {
        if (value) {
            selectFirebaseClass(value);
            populateAttendanceCheck();
        } else {
            // Clear global state
            AppState.activeClass = null;
            AppState.activeBatchId = null;
            AppState.attendanceRecords = [];
            AppState.attendanceHistory = {};

            // Clear view
            const container = document.getElementById('check-student-list');
            if (container) container.innerHTML = `<div style="text-align: center; padding: 40px; color: var(--text-secondary);">Select a batch to view students</div>`;

            // Visual Reset of Filters (Do not re-init logic, just clear UI)
            const branchTrigger = document.querySelector('#check-filter-branch-dropdown-wrapper .dropdown-text');
            if (branchTrigger) branchTrigger.textContent = 'Select Batch First';
            document.getElementById('check-filter-branch').value = '';
            document.getElementById('check-filter-branch-menu').innerHTML = '';

            const comboTrigger = document.querySelector('#check-filter-combo-dropdown-wrapper .dropdown-text');
            if (comboTrigger) comboTrigger.textContent = 'Select Batch First';
            document.getElementById('check-filter-combo').value = '';
            document.getElementById('check-filter-combo-menu').innerHTML = '';
        }
    });

    // Dashboard Class Dropdown
    const dashOptions = [
        { value: '', label: 'Select a batch...' },
        ...classes.map(c => ({ value: c.id, label: c.className }))
    ];
    initCustomDropdown('dashboard-class-dropdown-wrapper', 'dashboard-class-menu-portal', dashOptions, (value) => {
        if (value) {
            selectFirebaseClass(value);
            updateDashboard();
        }
    });

    // Scanner Batch Dropdown
    const scannerOptions = [
        { value: '', label: 'Select a batch...' },
        ...classes.map(c => ({ value: c.id, label: c.className }))
    ];
    initCustomDropdown('scanner-batch-dropdown-wrapper', 'scanner-batch-menu-portal', scannerOptions, (value) => {
        if (value) {
            selectFirebaseClass(value);
            showToast(`Scanning for: ${classes.find(c => c.id === value)?.className || value}`, 'info');
        }
    });

    // Interview Class Dropdown
    const interviewOptions = [
        { value: '', label: 'Select Batch...' },
        ...classes.map(c => ({ value: c.id, label: c.className }))
    ];
    initCustomDropdown('interview-class-dropdown-wrapper', 'interview-class-menu-portal', interviewOptions, (value) => {
        if (value) {
            const classData = classes.find(c => c.id === value);
            if (classData && classData.students) {
                const studentOptions = [
                    { value: '', label: 'Select Student...' },
                    ...classData.students.map(s => ({ value: s.pin, label: `${s.name} (${s.pin})` }))
                ];
                initInterviewStudentDropdown(studentOptions);
            }
        }
    });

    // Batch Dropdown in Settings
    const batchOptions = [
        { value: '', label: 'Select Batch...' },
        ...classes.map(c => ({ value: c.id, label: c.className }))
    ];
    initCustomDropdown('batch-dropdown-wrapper', 'batch-menu-portal', batchOptions, (value) => {
        updateSettingsClassList();
    });

    // Initialize Student Search Filters
    populateStudentSearchFilters();
}

/**
 * Populate filters for Student Search screen
 */
function populateStudentSearchFilters() {
    const classes = AppState.firebaseClasses || [];

    // 1. Batch Dropdown
    const batchOptions = [
        { value: '', label: 'All Batches' },
        ...classes.map(c => ({ value: c.id, label: c.className }))
    ];

    // Initialize Batch Dropdown
    initCustomDropdown('search-filter-batch-dropdown-wrapper', 'search-filter-batch-menu-portal', batchOptions, (value) => {
        // When batch changes, re-populate branch/combo and trigger search
        updateSearchFilterOptions(value);
        performStudentSearch();
    });

    // Initial population of Branch/Combo (with all data)
    updateSearchFilterOptions('');
}

function updateSearchFilterOptions(batchId) {
    let students = [];
    if (!AppState.firebaseClasses) return;

    if (batchId) {
        const batch = AppState.firebaseClasses.find(c => c.id === batchId);
        students = batch ? (batch.students || []) : [];
    } else {
        // Flatten all students
        AppState.firebaseClasses.forEach(c => {
            if (c.students) students.push(...c.students);
        });
    }

    const branches = new Set(students.map(s => s.branch).filter(b => b));
    const combos = new Set(students.map(s => s.combo).filter(c => c));

    // Branch Options
    const branchOptions = [
        { value: '', label: 'All Branches' },
        ...Array.from(branches).sort().map(b => ({ value: b, label: b }))
    ];

    // Combo Options
    const comboOptions = [
        { value: '', label: 'All Combos' },
        ...Array.from(combos).sort().map(c => ({ value: c, label: c }))
    ];

    // Re-initialize Branch Dropdown
    // Note: We need to reset value if current selection is not in new options
    const currentBranch = document.getElementById('search-filter-branch').value;
    const branchTrigger = document.querySelector('#search-filter-branch-dropdown-wrapper .dropdown-text');
    if (!branches.has(currentBranch) && branchTrigger) {
        branchTrigger.textContent = 'All Branches';
        document.getElementById('search-filter-branch').value = '';
    }

    initCustomDropdown('search-filter-branch-dropdown-wrapper', 'search-filter-branch-menu-portal', branchOptions, (value) => {
        performStudentSearch();
    });

    // Re-initialize Combo Dropdown
    const currentCombo = document.getElementById('search-filter-combo').value;
    const comboTrigger = document.querySelector('#search-filter-combo-dropdown-wrapper .dropdown-text');
    if (!combos.has(currentCombo) && comboTrigger) {
        comboTrigger.textContent = 'All Combos';
        document.getElementById('search-filter-combo').value = '';
    }

    initCustomDropdown('search-filter-combo-dropdown-wrapper', 'search-filter-combo-menu-portal', comboOptions, (value) => {
        performStudentSearch();
    });
}

/**
 * Select a Firebase class/batch as active
 */
function selectFirebaseClass(batchId) {
    const classData = (AppState.firebaseClasses || []).find(c => c.id === batchId);
    if (!classData) {
        console.warn('Batch not found:', batchId);
        return;
    }

    AppState.activeClass = classData;
    AppState.activeBatchId = batchId;
    AppState.attendanceRecords = [];
    AppState.syncPending = 0;

    // Load today's attendance from Firebase
    loadTodayAttendance(batchId);

    console.log('✅ Selected batch:', classData.className);
}

/**
 * Load today's attendance from Firebase
 */
async function loadTodayAttendance(batchId) {
    if (typeof FirebaseService === 'undefined') return;

    try {
        const today = FirebaseService.getTodayDateFormatted();
        const attendance = await FirebaseService.fetchAttendance(batchId, today);

        // Convert Firebase attendance to records format
        AppState.attendanceRecords = [];
        if (attendance) {
            Object.keys(attendance).forEach(pin => {
                const studentAttendance = attendance[pin];
                if (studentAttendance.scans) {
                    const scans = Object.values(studentAttendance.scans);
                    scans.forEach(scan => {
                        AppState.attendanceRecords.push({
                            pinNumber: pin,
                            studentName: getStudentName(pin),
                            status: 'present',
                            timestamp: scan.time,
                            session: scan.session,
                            method: scan.method,
                            synced: true
                        });
                    });
                }
            });
        }

        console.log(`✅ Loaded ${AppState.attendanceRecords.length} attendance records for ${today}`);

        // Refresh UI
        if (typeof renderBatchOverview === 'function') renderBatchOverview();
        if (typeof updateDashboard === 'function') updateDashboard();
        if (typeof updateAttendanceCheck === 'function') updateAttendanceCheck();

    } catch (error) {
        console.error('❌ Error loading attendance:', error);
    }
}

/**
 * Get student name by PIN from active class
 */
function getStudentName(pin) {
    if (!AppState.activeClass || !AppState.activeClass.students) return pin;
    const student = AppState.activeClass.students.find(s => s.pin === pin);
    return student ? student.name : pin;
}

/**
 * Mark attendance in Firebase
 */
async function markFirebaseAttendance(pin, method) {
    if (typeof FirebaseService === 'undefined') {
        console.error('FirebaseService not available');
        return false;
    }

    const batchId = AppState.activeBatchId;
    const today = FirebaseService.getTodayDateFormatted();
    const now = new Date();
    const timeStr = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    const session = now.getHours() < 12 ? 'morning' : 'afternoon';

    const scanData = {
        time: timeStr,
        session: session,
        method: method,
        markedAt: now.toISOString()
    };

    try {
        await FirebaseService.markAttendance(batchId, today, pin, scanData);

        // Add to local records
        AppState.attendanceRecords.push({
            pinNumber: pin,
            studentName: getStudentName(pin),
            status: 'present',
            timestamp: timeStr,
            session: session,
            method: method,
            synced: true
        });

        return true;
    } catch (error) {
        console.error('❌ Error marking attendance:', error);
        return false;
    }
}

// Session Class Dropdown
function initSessionClassDropdown() {
    const classes = AppState.firebaseClasses || mockData.classes;
    const options = [
        { value: '', label: 'Select a batch...' },
        ...classes.map(c => ({ value: c.id, label: `${c.className} (${c.classCode})` }))
    ];

    initCustomDropdown('session-class-dropdown-wrapper', 'session-class-menu-portal', options, (value, label) => {
        // No immediate action needed, value stored in hidden input
    });
}

// Attendance Check Class Dropdown
function initCheckClassDropdown() {
    const classes = AppState.firebaseClasses || mockData.classes;
    const options = [
        { value: '', label: 'Select a batch...' },
        ...classes.map(c => ({ value: c.id, label: c.className }))
    ];

    initCustomDropdown('check-class-dropdown-wrapper', 'check-class-menu-portal', options, (value, label) => {
        if (value) {
            if (AppState.firebaseClasses) {
                selectFirebaseClass(value);
            } else {
                selectClass(value);
            }
            populateAttendanceCheck(); // Re-populate filters and history
        }
    });
}

// Interview Class Dropdown
function initInterviewClassDropdown() {
    const classes = AppState.firebaseClasses || mockData.classes;
    const options = [
        { value: '', label: 'Select Class...' },
        ...classes.map(c => ({ value: c.id, label: `${c.className} (${c.classCode})` }))
    ];

    initCustomDropdown('interview-class-dropdown-wrapper', 'interview-class-menu-portal', options, (value, label) => {
        // Update student dropdown when class is selected
        if (value) {
            const classData = classes.find(c => c.id === value);
            if (classData) {
                const studentOptions = [
                    { value: '', label: 'Select Student...' },
                    ...classData.students.map(s => ({ value: s.pinNumber || s.pin, label: `${s.name} (${s.pinNumber || s.pin})` }))
                ];
                initInterviewStudentDropdown(studentOptions);
            }
        } else {
            initInterviewStudentDropdown([{ value: '', label: 'Select Student...' }]);
        }
    });
}

// Interview Student Dropdown
function initInterviewStudentDropdown(options) {
    if (options.length === 0) {
        options = [{ value: '', label: 'Select Student...' }];
    }

    initCustomDropdown('interview-student-dropdown-wrapper', 'interview-student-menu-portal', options, (value, label) => {
        // Student selected
    });

    // Reset the dropdown text
    const textSpan = document.querySelector('#interview-student-dropdown-wrapper .dropdown-text');
    if (textSpan) {
        textSpan.textContent = 'Select Student...';
    }
    const hiddenInput = document.getElementById('interview-student-dropdown');
    if (hiddenInput) {
        hiddenInput.value = '';
    }
}

// Batch Dropdown
function initBatchDropdown() {
    const options = [
        { value: '', label: 'Select Batch...' },
        ...mockData.batches.map(b => ({ value: b.id, label: b.name }))
    ];

    initCustomDropdown('batch-dropdown-wrapper', 'batch-menu-portal', options, (value, label) => {
        updateSettingsClassList();
    });
}

function selectClass(classId) {
    const classData = mockData.classes.find(c => c.id === classId);
    if (!classData) return;

    AppState.activeClass = classData;
    AppState.attendanceRecords = mockData.generateTodayAttendance(classId);
    AppState.syncPending = AppState.attendanceRecords.filter(r => !r.synced).length;
}

// ==========================================
// NAVIGATION HELPERS
// ==========================================
function showScreen(screenId) {
    // Hide all screens
    document.querySelectorAll('.screen').forEach(s => {
        s.classList.add('hidden');
        s.classList.remove('active');
    });

    // Show target
    const target = document.getElementById(screenId);
    if (target) {
        target.classList.remove('hidden');
        target.classList.add('active');
    } else {
        console.error(`Screen not found: ${screenId}`);
    }
}

const ROOT_SCREENS = ['home-screen', 'dashboard-screen', 'settings-screen'];

function updateBottomNavVisibility(screenId) {
    const nav = document.querySelector('.bottom-nav');
    if (!nav) return;

    // Check if target is a root screen
    if (ROOT_SCREENS.includes(screenId)) {
        nav.classList.remove('hidden-down');
    } else {
        nav.classList.add('hidden-down');
    }
}

function navigateToScreen(screenId, addToStack = true) {
    const currentScreenId = AppState.currentScreen;

    if (addToStack && currentScreenId && currentScreenId !== screenId) {
        // Don't push if we are just refreshing the same screen
        AppState.navigationStack.push(currentScreenId);
    }

    // Animation Logic
    const currentScreen = document.getElementById(currentScreenId);
    const nextScreen = document.getElementById(screenId);

    if (currentScreen && nextScreen && currentScreenId !== screenId) {
        // Forward Transition
        currentScreen.classList.add('anim-slide-out-left');
        nextScreen.classList.add('anim-slide-in-right');
        nextScreen.classList.remove('hidden');
        nextScreen.classList.add('active');

        // Cleanup classes after animation
        setTimeout(() => {
            currentScreen.classList.remove('anim-slide-out-left', 'active');
            currentScreen.classList.add('hidden');
            nextScreen.classList.remove('anim-slide-in-right');
        }, 300);
    } else {
        // Fallback for first load or same screen
        showScreen(screenId);
    }

    AppState.currentScreen = screenId;
    updateBottomNavVisibility(screenId);
}

// ==========================================
// BOTTOM NAVIGATION - Matches Flutter CurvedBottomNavigation
// ==========================================
function initBottomNavigation() {
    const navItems = document.querySelectorAll('.bottom-nav .nav-item');

    navItems.forEach((item, index) => {
        item.addEventListener('click', function () {
            navigateToTab(index);
        });
    });
}

function navigateToTab(tabIndex) {
    AppState.currentTab = tabIndex;
    AppState.navigationStack = []; // Clear stack when switching main tabs

    // Ensure Bottom Nav is visible
    const nav = document.querySelector('.bottom-nav');
    if (nav) nav.classList.remove('hidden-down');

    // Update nav items
    const navItems = document.querySelectorAll('.bottom-nav .nav-item');
    navItems.forEach((item, i) => {
        item.classList.toggle('active', i === tabIndex);
    });

    // Hide all screens
    document.querySelectorAll('.screen').forEach(screen => {
        screen.classList.add('hidden');
    });

    // Show target screen based on tab
    const screens = ['home-screen', 'dashboard-screen', 'settings-screen'];
    const targetScreen = document.getElementById(screens[tabIndex]);
    if (targetScreen) {
        targetScreen.classList.remove('hidden');
    }

    // Tab-specific initialization
    if (tabIndex === 1) {
        updateDashboard();
    } else if (tabIndex === 2) {
        updateSettingsClassList();
    }
}


function navigateBack() {
    if (AppState.navigationStack && AppState.navigationStack.length > 0) {
        const prevScreenId = AppState.navigationStack.pop();
        const currentScreenId = AppState.currentScreen;

        // Animation Logic for Back
        const currentScreen = document.getElementById(currentScreenId);
        const prevScreen = document.getElementById(prevScreenId);

        if (currentScreen && prevScreen) {
            currentScreen.classList.add('anim-slide-out-right');
            prevScreen.classList.add('anim-slide-in-left');
            prevScreen.classList.remove('hidden');
            prevScreen.classList.add('active');

            setTimeout(() => {
                currentScreen.classList.remove('anim-slide-out-right', 'active');
                currentScreen.classList.add('hidden');
                prevScreen.classList.remove('anim-slide-in-left');
            }, 300);

            AppState.currentScreen = prevScreenId;
            updateBottomNavVisibility(prevScreenId);
        } else {
            // Fallback if elements missing
            navigateToScreen(prevScreenId, false);
        }
    } else {
        navigateToTab(0); // Fallback to home
    }
}

// ==========================================
// HOME SCREEN - Mode Selection Cards
// ==========================================
function initHomeScreenEvents() {
    // Attendance Card - Check button
    document.getElementById('check-attendance-btn').addEventListener('click', function () {
        navigateToScreen('attendance-check-screen');
        populateAttendanceCheck();
    });

    // Attendance Card - Scan button
    document.getElementById('scan-attendance-btn').addEventListener('click', function () {
        if (AppState.activeClass) {
            navigateToScreen('scanner-screen');
            updateScannerInfo();
        } else {
            navigateToScreen('session-setup-screen');
        }
    });

    // Class Details button
    document.getElementById('view-class-btn').addEventListener('click', function () {
        navigateToScreen('class-details-screen');
        renderClassList();
    });

    // Student Search button
    document.getElementById('search-student-btn').addEventListener('click', function () {
        navigateToScreen('student-search-screen');
    });

    // Mock Interview button
    document.getElementById('start-interview-btn').addEventListener('click', function () {
        navigateToScreen('mock-interview-screen');
    });
}

// ==========================================
// SESSION SETUP SCREEN
// ==========================================
function initSessionSetupEvents() {
    // Back button
    document.getElementById('session-back-btn').addEventListener('click', navigateBack);

    // Session type toggle is now handled by initSessionSetupScreenEvents

    // Start session button
    document.getElementById('start-session-btn').addEventListener('click', function () {
        const classId = document.getElementById('session-class-dropdown').value;
        if (!classId) {
            showToast('Please select a batch', 'warning');
            return;
        }

        // Use Firebase or mock class selection
        if (typeof FirebaseService !== 'undefined' && AppState.firebaseClasses) {
            selectFirebaseClass(classId);
        } else {
            selectClass(classId);
        }

        navigateToScreen('scanner-screen');
        updateScannerInfo();
        showToast(`Session started: ${AppState.activeClass.className} (${AppState.sessionType})`, 'success');
    });
}

// ==========================================
// SCANNER SCREEN
// ==========================================
function initScannerScreenEvents() {
    // Back button
    document.getElementById('scanner-back-btn').addEventListener('click', navigateBack);

    // Scanner frame - simulate QR scan
    document.getElementById('scanner-frame').addEventListener('click', simulateQRScan);

    // Manual PIN entry
    document.getElementById('submit-pin-btn').addEventListener('click', handleManualPinEntry);
    document.getElementById('manual-pin').addEventListener('keypress', function (e) {
        if (e.key === 'Enter') handleManualPinEntry();
    });
}

function updateScannerInfo() {
    if (AppState.activeClass) {
        // Update class name text if it exists (legacy)
        const classNameEl = document.getElementById('scanner-class-name');
        if (classNameEl) {
            classNameEl.textContent = AppState.activeClass.className;
        }

        // Update session display
        const sessionEl = document.getElementById('scanner-session-display') || document.getElementById('scanner-session-type');
        if (sessionEl) {
            sessionEl.textContent = AppState.sessionType === 'morning' ? 'Morning' : 'Afternoon';
        }

        // Update scanner dropdown if it exists
        const scannerDropdown = document.getElementById('scanner-batch-dropdown');
        if (scannerDropdown) {
            scannerDropdown.value = AppState.activeClass.id;
            // Also update the trigger text if using custom dropdown
            const triggerText = document.querySelector('#scanner-batch-dropdown-wrapper .dropdown-text');
            if (triggerText) {
                triggerText.textContent = AppState.activeClass.className;
            }
        }
    }
}

function simulateQRScan() {
    if (!AppState.activeClass) {
        showToast('Please select a batch first', 'warning');
        return;
    }

    // Get students - handle both mock (pinNumber) and Firebase (pin) format
    const students = AppState.activeClass.students || [];
    if (students.length === 0) {
        showToast('No students in this batch', 'warning');
        return;
    }

    // Random student for simulation
    const randomStudent = students[Math.floor(Math.random() * students.length)];
    const pin = randomStudent.pin || randomStudent.pinNumber;

    processAttendance(pin, 'qr');
}

function handleManualPinEntry() {
    const input = document.getElementById('manual-pin');
    const pin = input.value.trim().toUpperCase();

    if (!pin) {
        showToast('Please enter a PIN number', 'warning');
        return;
    }

    processAttendance(pin, 'manual');
    input.value = '';
}

async function processAttendance(pin, method) {
    if (!AppState.activeClass) {
        showToast('Please select a class first', 'warning');
        return;
    }

    // Find student - handle both mock (pinNumber) and Firebase (pin) format
    const students = AppState.activeClass.students || [];
    const student = students.find(s => (s.pin || s.pinNumber) === pin);

    if (!student) {
        showScanResult(false, { pin });
        return;
    }

    const studentName = student.name;
    const studentPin = student.pin || student.pinNumber;

    // Try Firebase first, fallback to local
    if (typeof FirebaseService !== 'undefined' && AppState.activeBatchId) {
        const success = await markFirebaseAttendance(studentPin, method);
        if (success) {
            showScanResult(true, { student: { name: studentName, pinNumber: studentPin } });
            updateRecentScans();
            showToast(`${studentName} marked present!`, 'success');
        } else {
            showToast('Failed to mark attendance. Try again.', 'error');
        }
    } else {
        // Fallback to local storage
        const record = {
            id: `att-${Date.now()}`,
            pinNumber: studentPin,
            studentName: studentName,
            classId: AppState.activeClass.id,
            date: AppState.sessionDate,
            timestamp: new Date().toISOString(),
            status: 'present',
            scanMethod: method,
            sessionType: AppState.sessionType,
            synced: false
        };

        AppState.attendanceRecords.push(record);
        AppState.syncPending++;
        AppState.recentScans.unshift(record);
        if (AppState.recentScans.length > 10) AppState.recentScans.pop();

        showScanResult(true, { student: { name: studentName, pinNumber: studentPin }, record });
        updateRecentScans();
    }
}

function showScanResult(success, data) {
    const resultDiv = document.getElementById('scan-result');

    if (success) {
        resultDiv.className = 'scan-result success';
        resultDiv.innerHTML = `
            <div class="result-icon"><i class="fas fa-check-circle"></i></div>
            <div class="result-info">
                <span class="result-name">${data.student.name}</span>
                <span class="result-pin">PIN: ${data.student.pinNumber}</span>
            </div>
        `;
    } else {
        resultDiv.className = 'scan-result error';
        resultDiv.innerHTML = `
            <div class="result-icon"><i class="fas fa-times-circle"></i></div>
            <div class="result-info">
                <span class="result-name">Invalid PIN</span>
                <span class="result-pin">${data.pin}</span>
            </div>
        `;
    }

    resultDiv.classList.remove('hidden');
    setTimeout(() => resultDiv.classList.add('hidden'), 2000);
}

function updateRecentScans() {
    const container = document.getElementById('recent-scans-list');
    const scans = AppState.recentScans;

    if (scans.length === 0) {
        container.innerHTML = `<div style="text-align: center; padding: 20px; color: var(--text-secondary);">No recent scans</div>`;
        return;
    }

    container.innerHTML = scans.map(scan => `
        <div class="student-item">
            <div class="student-avatar">${scan.studentName.charAt(0)}</div>
            <div class="student-info">
                <div class="student-name">${scan.studentName}</div>
                <div class="student-pin">${scan.pinNumber}</div>
            </div>
            <span class="student-status present">${formatTime(scan.timestamp)}</span>
        </div>
    `).join('');
}

// ==========================================
// ATTENDANCE CHECK SCREEN
// ==========================================
function initAttendanceCheckEvents() {
    document.getElementById('attendance-check-back-btn').addEventListener('click', navigateBack);

    // Search Input
    document.getElementById('check-student-search').addEventListener('input', function () {
        renderCheckStudentList();
    });
}

async function populateAttendanceCheck() {
    if (AppState.activeClass) {
        // Update the custom dropdown display text
        const textSpan = document.querySelector('#check-class-dropdown-wrapper .dropdown-text');
        if (textSpan) {
            textSpan.textContent = AppState.activeClass.className;
        }
        document.getElementById('check-class-dropdown').value = AppState.activeClass.id;

        // Fetch History
        if (typeof FirebaseService !== 'undefined') {
            try {
                const history = await FirebaseService.fetchBatchAttendanceHistory(AppState.activeClass.id);
                AppState.attendanceHistory = history || {};
            } catch (error) {
                console.error('Failed to fetch attendance history:', error);
                AppState.attendanceHistory = {};
            }
        } else {
            AppState.attendanceHistory = {}; // Fallback/Mock
        }

        // Populate Filters
        const students = AppState.activeClass.students || [];
        const branches = new Set(students.map(s => s.branch).filter(b => b));
        const combos = new Set(students.map(s => s.combo).filter(c => c));

        // Branch Options
        const branchOptions = [
            { value: '', label: 'All Branches' },
            ...Array.from(branches).map(b => ({ value: b, label: b }))
        ];

        // Combo Options
        const comboOptions = [
            { value: '', label: 'All Combos' },
            ...Array.from(combos).map(c => ({ value: c, label: c }))
        ];

        // Initialize Custom Dropdowns
        const branchTrigger = document.querySelector('#check-filter-branch-dropdown-wrapper .dropdown-text');
        if (branchTrigger) branchTrigger.textContent = 'All Branches';
        document.getElementById('check-filter-branch').value = '';

        initCustomDropdown('check-filter-branch-dropdown-wrapper', 'check-filter-branch-menu-portal', branchOptions, (value) => {
            renderCheckStudentList();
        });

        const comboTrigger = document.querySelector('#check-filter-combo-dropdown-wrapper .dropdown-text');
        if (comboTrigger) comboTrigger.textContent = 'All Combos';
        document.getElementById('check-filter-combo').value = '';

        initCustomDropdown('check-filter-combo-dropdown-wrapper', 'check-filter-combo-menu-portal', comboOptions, (value) => {
            renderCheckStudentList();
        });

        // Reset Search
        document.getElementById('check-student-search').value = '';

        updateAttendanceCheck();
    }
}

function updateAttendanceCheck() {
    if (!AppState.activeClass) return;
    renderCheckStudentList();
}

function renderCheckStudentList() {
    if (!AppState.activeClass) return;

    const container = document.getElementById('check-student-list');

    // Calculate Stats for each student
    const history = AppState.attendanceHistory || {};
    const totalDays = Object.keys(history).length;

    // Get Filter Values
    const searchQuery = document.getElementById('check-student-search').value.toLowerCase();
    const branchFilter = document.getElementById('check-filter-branch').value;
    const comboFilter = document.getElementById('check-filter-combo').value;

    let students = AppState.activeClass.students || [];

    // 1. Filter by Search
    if (searchQuery) {
        students = students.filter(s =>
            s.name.toLowerCase().includes(searchQuery) ||
            (s.pin || s.pinNumber || '').toLowerCase().includes(searchQuery)
        );
    }

    // 2. Filter by Branch
    if (branchFilter) {
        students = students.filter(s => s.branch === branchFilter);
    }

    // 3. Filter by Combo
    if (comboFilter) {
        students = students.filter(s => s.combo === comboFilter);
    }

    if (students.length === 0) {
        container.innerHTML = `<div style="text-align: center; padding: 40px; color: var(--text-secondary);">No students found</div>`;
        return;
    }

    container.innerHTML = students.map(student => {
        const pin = student.pin || student.pinNumber; // Robust property access

        // Calculate attendance stats
        let presentDays = 0;
        if (history) {
            Object.values(history).forEach(dateRecord => {
                if (dateRecord && dateRecord[pin]) {
                    presentDays++;
                }
            });
        }
        const percentage = totalDays > 0 ? ((presentDays / totalDays) * 100).toFixed(1) : '0.0';

        // Determine status badge color based on percentage
        let statusClass = 'absent'; // Red by default
        if (percentage >= 75) statusClass = 'present'; // Green
        else if (percentage >= 50) statusClass = 'warning'; // Yellow/Orange (need CSS for this if desired, or keep as simple present/absent)

        return `
            <div class="student-item" onclick="showStudentDetails('${pin}')">
                <div class="student-avatar">${student.name.charAt(0)}</div>
                <div class="student-info">
                    <div class="student-name">${student.name}</div>
                    <div class="student-pin">${pin} • ${student.branch}</div>
                </div>
                <div style="text-align: right;">
                    <div style="font-weight: 600; color: var(--text-primary);">${presentDays}/${totalDays} Days</div>
                    <div style="font-size: 0.8rem; color: var(--text-secondary);">${percentage}%</div>
                </div>
            </div>
        `;
    }).join('');
}

// ==========================================
// CLASS DETAILS SCREEN
// ==========================================
function initClassDetailsEvents() {
    document.getElementById('class-details-back-btn').addEventListener('click', navigateBack);
}

function renderClassList() {
    const container = document.getElementById('class-list-container');
    const classes = AppState.firebaseClasses || mockData.classes;

    if (classes.length === 0) {
        container.innerHTML = `<div style="text-align: center; padding: 20px; color: var(--text-secondary);">No batches found</div>`;
        return;
    }

    container.innerHTML = classes.map(classData => `
        <div class="glass-card" style="padding: var(--medium-spacing); margin-bottom: var(--medium-spacing); cursor: pointer;" 
             onclick="selectAndViewClass('${classData.id}')">
            <div style="display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <div style="font-weight: 600; font-size: 1.125rem;">${classData.className}</div>
                    <div style="color: var(--text-secondary); font-size: 0.875rem;">${(classData.students || []).length} students</div>
                    ${classData.batchId ? `<div style="color: var(--text-muted); font-size: 0.75rem; margin-top: 4px;">Batch: ${classData.batchId}</div>` : ''}
                </div>
                <i class="fas fa-chevron-right" style="color: var(--techwing-orange);"></i>
            </div>
        </div>
    `).join('');
}

function selectAndViewClass(classId) {
    if (AppState.firebaseClasses) {
        selectFirebaseClass(classId);
    } else {
        selectClass(classId);
    }
    navigateToScreen('batch-overview-screen');
    renderBatchOverview();
}

// ==========================================
// BATCH OVERVIEW SCREEN
// ==========================================
function initBatchOverviewEvents() {
    document.getElementById('batch-overview-back-btn').addEventListener('click', navigateBack);

    // Actions
    document.getElementById('batch-check-btn').addEventListener('click', function () {
        navigateToScreen('attendance-check-screen');
        populateAttendanceCheck();
    });

    document.getElementById('batch-session-btn').addEventListener('click', function () {
        navigateToScreen('scanner-screen');
        updateScannerInfo();
        showToast(`Session started: ${AppState.activeClass.className}`, 'success');
    });

    // Filter Change Events - Now handled by custom dropdown callbacks
    // document.getElementById('batch-filter-branch').addEventListener('change', renderBatchStudentList);
    // document.getElementById('batch-filter-combo').addEventListener('change', renderBatchStudentList);
}

function renderBatchOverview() {
    if (!AppState.activeClass) return;

    const classData = AppState.activeClass;
    document.getElementById('batch-overview-title').textContent = classData.className;

    // Calculate Stats
    const students = classData.students || [];
    const totalStudents = students.length;

    // Present Today
    const presentCount = AppState.attendanceRecords.filter(r => r.status === 'present').length;
    const absentCount = totalStudents - presentCount;

    document.getElementById('batch-total-students').textContent = totalStudents;
    document.getElementById('batch-present-today').textContent = presentCount;
    document.getElementById('batch-absent-today').textContent = absentCount;
    document.getElementById('batch-last-sync').textContent = formatTime(new Date());

    // Populate Filters
    populateBatchFilters(students);

    // Render Student List
    renderBatchStudentList();
}

function populateBatchFilters(students) {
    // Parse Branches
    const branches = new Set(students.map(s => s.branch).filter(b => b));
    const combos = new Set(students.map(s => s.combo).filter(c => c));

    // Branch Options
    const branchOptions = [
        { value: '', label: 'All Branches' },
        ...Array.from(branches).map(b => ({ value: b, label: b }))
    ];

    // Combo Options
    const comboOptions = [
        { value: '', label: 'All Combos' },
        ...Array.from(combos).map(c => ({ value: c, label: c }))
    ];

    // Initialize Custom Dropdowns
    const branchTrigger = document.querySelector('#batch-filter-branch-dropdown-wrapper .dropdown-text');
    if (branchTrigger) branchTrigger.textContent = 'All Branches';
    document.getElementById('batch-filter-branch').value = '';

    initCustomDropdown('batch-filter-branch-dropdown-wrapper', 'batch-filter-branch-menu-portal', branchOptions, (value) => {
        renderBatchStudentList();
    });

    const comboTrigger = document.querySelector('#batch-filter-combo-dropdown-wrapper .dropdown-text');
    if (comboTrigger) comboTrigger.textContent = 'All Combos';
    document.getElementById('batch-filter-combo').value = '';

    initCustomDropdown('batch-filter-combo-dropdown-wrapper', 'batch-filter-combo-menu-portal', comboOptions, (value) => {
        renderBatchStudentList();
    });
}

function renderBatchStudentList() {
    if (!AppState.activeClass) return;

    const container = document.getElementById('batch-student-list');
    const branchFilter = document.getElementById('batch-filter-branch').value;
    const comboFilter = document.getElementById('batch-filter-combo').value;

    let students = AppState.activeClass.students || [];

    // Apply Filters
    if (branchFilter) {
        students = students.filter(s => s.branch === branchFilter);
    }
    if (comboFilter) {
        students = students.filter(s => s.combo === comboFilter);
    }

    // Update Count
    document.getElementById('batch-student-count').textContent = students.length;

    if (students.length === 0) {
        container.innerHTML = `<div style="text-align: center; padding: 40px; color: var(--text-secondary);">No students found matching filters</div>`;
        return;
    }

    // Get attendance map for quick lookup
    const attendanceMap = new Map();
    AppState.attendanceRecords.forEach(r => {
        attendanceMap.set(r.pinNumber, r);
    });

    container.innerHTML = students.map(student => {
        const pin = student.pin || student.pinNumber;
        const record = attendanceMap.get(pin);
        const isPresent = !!record;
        const showDelete = AppState.userRole === 'admin';

        return `
        <div class="glass-card" style="padding: 15px; margin-bottom: 10px; display: flex; align-items: center;">
            <div class="student-avatar" style="margin-right: 15px;">${student.name.charAt(0)}</div>
            <div style="flex: 1;">
                <div style="font-weight: 600; font-size: 1rem;">${student.name}</div>
                <div style="color: var(--text-secondary); font-size: 0.85rem; margin-top: 2px;">
                    ${pin} • ${student.branch || 'N/A'} • ${student.combo || 'N/A'}
                </div>
            </div>
            <div style="text-align: right; display: flex; align-items: center; gap: 10px;">
                <span class="student-status ${isPresent ? 'present' : 'absent'}" style="font-size: 0.75rem; padding: 4px 8px;">
                    ${isPresent ? 'Present' : 'Absent'}
                </span>
                ${showDelete ? `<button class="icon-btn danger" onclick="deleteStudent('${pin}')" title="Delete Student" style="width: 28px; height: 28px;">
                    <i class="fas fa-trash" style="font-size: 0.8rem;"></i>
                </button>` : ''}
            </div>
        </div>
        `;
    }).join('');
}

async function deleteStudent(pin) {
    if (!AppState.activeClass) return;

    // Admin guard
    if (AppState.userRole !== 'admin') {
        showToast('Admin access required to delete students', 'warning');
        return;
    }

    if (confirm(`Are you sure you want to delete student with PIN: ${pin}?`)) {
        try {
            await FirebaseService.deleteStudent(AppState.activeClass.id, pin);
            showToast('Student deleted successfully', 'success');

            // Quick Refresh
            const students = await FirebaseService.fetchStudents(AppState.activeClass.id);
            AppState.activeClass.students = Object.values(students || {});

            // Update global batch list reference
            if (AppState.batches[AppState.activeClass.id]) {
                AppState.batches[AppState.activeClass.id].students = students;
            }

            renderBatchOverview();
        } catch (error) {
            console.error('Delete student error:', error);
            showToast('Failed to delete student', 'error');
        }
    }
}

// ==========================================
// STUDENT SEARCH SCREEN
// ==========================================
function initStudentSearchEvents() {
    document.getElementById('student-search-back-btn').addEventListener('click', navigateBack);

    const searchInput = document.getElementById('student-search-input');
    const searchBtn = document.getElementById('search-btn');

    let debounceTimer;
    searchInput.addEventListener('input', function () {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => performStudentSearch(this.value), 300);
    });

    searchBtn.addEventListener('click', function () {
        performStudentSearch(searchInput.value);
    });
}

// Helper to search students (Mock + Firebase)
function searchAllStudents(query) {
    if (!query) return [];

    // If Firebase data exists, search it
    if (AppState.firebaseClasses) {
        const results = [];
        const queryLower = query.toLowerCase();

        AppState.firebaseClasses.forEach(classData => {
            if (classData.students) {
                classData.students.forEach(student => {
                    const pin = student.pin || student.pinNumber || '';
                    const email = student.email || '';

                    if (student.name.toLowerCase().includes(queryLower) ||
                        pin.toLowerCase().includes(queryLower) ||
                        email.toLowerCase().includes(queryLower)) {
                        results.push({
                            ...student,
                            className: classData.className,
                            classId: classData.id
                        });
                    }
                });
            }
        });
        return results;
    }

    // Fallback to mock data
    return mockData.searchStudents(query);
}

function performStudentSearch(queryOverride) {
    const container = document.getElementById('search-results-list');
    const countEl = document.getElementById('search-results-count');

    // Get Search Query (argument or input)
    let query = queryOverride;
    if (typeof query !== 'string') {
        const input = document.getElementById('student-search-input');
        query = input ? input.value : '';
    }

    // Get Filter Values
    const batchFilter = document.getElementById('search-filter-batch') ? document.getElementById('search-filter-batch').value : '';
    const branchFilter = document.getElementById('search-filter-branch') ? document.getElementById('search-filter-branch').value : '';
    const comboFilter = document.getElementById('search-filter-combo') ? document.getElementById('search-filter-combo').value : '';

    if (!query.trim() && !batchFilter && !branchFilter && !comboFilter) {
        container.innerHTML = `<div style="text-align: center; padding: 40px; color: var(--text-secondary);">Enter a name/PIN or select filters</div>`;
        countEl.textContent = '0';
        return;
    }

    // Filter Logic
    let results = [];
    if (AppState.firebaseClasses) {
        const queryLower = query.toLowerCase().trim();

        AppState.firebaseClasses.forEach(classData => {
            // 1. Batch Filter
            if (batchFilter && classData.id !== batchFilter) return;

            if (classData.students) {
                classData.students.forEach(student => {
                    const pin = student.pin || student.pinNumber || '';
                    const email = student.email || '';

                    // 2. Branch Filter
                    if (branchFilter && student.branch !== branchFilter) return;

                    // 3. Combo Filter
                    if (comboFilter && student.combo !== comboFilter) return;

                    // 4. Search Query
                    if (!queryLower ||
                        student.name.toLowerCase().includes(queryLower) ||
                        pin.toLowerCase().includes(queryLower) ||
                        email.toLowerCase().includes(queryLower)) {

                        results.push({
                            ...student,
                            className: classData.className,
                            classId: classData.id
                        });
                    }
                });
            }
        });
    } else {
        // Mock fallback (simplified)
        results = searchAllStudents(query);
    }

    countEl.textContent = results.length;

    if (results.length === 0) {
        container.innerHTML = `<div style="text-align: center; padding: 40px; color: var(--text-secondary);">No students found</div>`;
        return;
    }

    container.innerHTML = results.map(student => {
        const pin = student.pin || student.pinNumber;
        return `
        <div class="student-item" onclick="showStudentDetails('${pin}')">
            <div class="student-avatar">${student.name.charAt(0)}</div>
            <div class="student-info">
                <div class="student-name">${student.name}</div>
                <div class="student-pin">${pin} • ${student.branch}</div>
            </div>
            <i class="fas fa-chevron-right" style="color: var(--techwing-orange);"></i>
        </div>
    `}).join('');
}

// ==========================================
// STUDENT DETAILS SCREEN
// ==========================================
// ==========================================
// STUDENT DETAILS SCREEN
// ==========================================
async function showStudentDetails(pinNumber) {
    let student = null;
    let batchId = null;

    // 1. Try finding in active class (most likely context)
    if (AppState.activeClass && AppState.activeClass.students) {
        student = AppState.activeClass.students.find(s =>
            String(s.pin || s.pinNumber) === String(pinNumber)
        );
        if (student) batchId = AppState.activeClass.id;
    }

    // 2. Fallback to global search (if not found in active class)
    if (!student) {
        // We need to find which batch this student belongs to
        // searchAllStudents returns students with classId attached
        const searchResults = searchAllStudents(pinNumber);
        student = searchResults.find(s => String(s.pin || s.pinNumber) === String(pinNumber));
        if (student) batchId = student.classId;
    }

    if (!student) {
        showToast('Student not found', 'error');
        return;
    }

    const pin = student.pin || student.pinNumber; // Robust PIN

    document.getElementById('detail-student-name').textContent = student.name;
    document.getElementById('detail-student-pin').textContent = `PIN: ${pin}`;
    document.getElementById('detail-email').textContent = student.email || '-';
    document.getElementById('detail-phone').textContent = student.phone || '-';
    document.getElementById('detail-branch').textContent = student.branch || '-';
    document.getElementById('detail-combo').textContent = student.combo || '-';

    // --- Calculate Attendance Stats ---

    // Ensure we have history for this batch
    let history = AppState.attendanceHistory;

    // If we came from global search (different batch) or history is missing/empty
    // We should try to fetch it if we have a batchId and FirebaseService
    if ((!history || Object.keys(history).length === 0 || (AppState.activeClass && AppState.activeClass.id !== batchId)) && batchId && typeof FirebaseService !== 'undefined') {
        try {
            // Quick fetch for this student's stats - effectively fetching batch history
            // Optimization: If we could fetch single student history that would be better, 
            // but our current structure is batch-centric. Fetching batch history is okay.
            const fetchedHistory = await FirebaseService.fetchBatchAttendanceHistory(batchId);
            history = fetchedHistory || {};
            // Note: We don't overwrite AppState.attendanceHistory if we are in a different batch context
            // to avoid confusing the main Attendance Check screen. 
            // But if we are "viewing" this student, maybe we don't mind. 
            // Let's use local variable for calculation.
        } catch (e) {
            console.error("Failed to fetch history for profile:", e);
            history = {};
        }
    } else if (!history) {
        history = {};
    }

    const totalDays = Object.keys(history).length;
    let presentDays = 0;
    const historyList = [];

    // Sort dates descending (newest first)
    const sortedDates = Object.keys(history).sort((a, b) => new Date(b) - new Date(a));

    sortedDates.forEach(date => {
        const dayRecord = history[date];
        let status = 'Absent';
        let statusClass = 'absent'; // Red

        if (dayRecord && dayRecord[pin]) {
            presentDays++;
            status = 'Present';
            statusClass = 'present'; // Green
        }

        // Format Date (e.g., "Mon, 08 Feb 2026")
        const dateObj = new Date(date);
        const dateStr = dateObj.toLocaleDateString('en-US', { weekday: 'short', day: '2-digit', month: 'short', year: 'numeric' });

        historyList.push(`
            <div style="display: flex; justify-content: space-between; align-items: center; padding: 10px; background: rgba(255,255,255,0.05); border-radius: 8px;">
                <div style="font-weight: 500;">${dateStr}</div>
                <div class="status-badge ${statusClass}" style="font-size: 0.8rem; padding: 4px 10px;">${status}</div>
            </div>
        `);
    });

    const percentage = totalDays > 0 ? ((presentDays / totalDays) * 100).toFixed(1) : '0.0';

    // Update UI Stats
    document.getElementById('detail-attendance-percent').textContent = `${percentage}%`;
    document.getElementById('detail-attendance-percent').style.color = percentage >= 75 ? 'var(--success-color)' : (percentage >= 50 ? 'var(--warning-color)' : 'var(--error-color)');

    document.getElementById('detail-present-days').textContent = presentDays;
    document.getElementById('detail-total-days').textContent = totalDays;

    // Update History List
    const historyContainer = document.getElementById('detail-history-list');
    if (historyContainer) {
        if (historyList.length > 0) {
            historyContainer.innerHTML = historyList.join('');
        } else {
            historyContainer.innerHTML = `<div style="text-align: center; color: var(--text-muted); padding: 10px;">No attendance records found</div>`;
        }
    }

    navigateToScreen('student-details-screen');

    document.getElementById('student-details-back-btn').onclick = function () {
        navigateBack();
    };
}

// ==========================================
// MOCK INTERVIEW SCREEN
// ==========================================
// ==========================================
// MOCK INTERVIEW SCREEN
// ==========================================
function initMockInterviewEvents() {
    // PIN Input - Fetch details on blur or Enter
    const pinInput = document.getElementById('interview-student-pin-input');
    if (pinInput) {
        pinInput.addEventListener('blur', function () {
            if (this.value.trim()) fetchStudentAndConfirm(this.value.trim());
        });
        pinInput.addEventListener('keypress', function (e) {
            if (e.key === 'Enter') {
                this.blur(); // Trigger blur
            }
        });
    }

    // Resume Score Slider
    const resumeSlider = document.getElementById('resume-score-slider');
    const resumeDisplay = document.getElementById('resume-score-display');
    if (resumeSlider && resumeDisplay) {
        resumeSlider.addEventListener('input', function () {
            resumeDisplay.textContent = this.value;
        });
    }

    // Metric Sliders
    document.querySelectorAll('.metric-slider').forEach(slider => {
        slider.addEventListener('input', function () {
            this.nextElementSibling.textContent = this.value;
        });
    });

    // Save/Clear buttons
    document.getElementById('save-interview-btn').addEventListener('click', saveInterview);
    document.getElementById('clear-interview-btn').addEventListener('click', clearInterview);

    // Start New Interview Button
    const startNewBtn = document.getElementById('start-new-interview-btn');
    if (startNewBtn) {
        startNewBtn.addEventListener('click', startNewInterview);
    }

    // Active Interview Back Button
    const activeBackBtn = document.getElementById('active-interview-back-btn');
    if (activeBackBtn) {
        activeBackBtn.addEventListener('click', () => {
            navigateBack();
        });
    }

    // Mock Interview Screen Back Button (Return to Dashboard)
    const mockBackBtn = document.getElementById('interview-back-btn');
    if (mockBackBtn) {
        mockBackBtn.addEventListener('click', () => {
            navigateBack();
        });
    }

    // Modal Close
    const closeModal = document.getElementById('close-interview-modal');
    if (closeModal) {
        closeModal.addEventListener('click', () => {
            document.getElementById('interview-detail-modal').classList.add('hidden');
        });
    }

    // Close modal on outside click
    window.addEventListener('click', (e) => {
        const modal = document.getElementById('interview-detail-modal');
        if (e.target === modal) {
            modal.classList.add('hidden');
        }
    });
}

// Global scope for HTML onchange access
window.toggleRound = function (round) {
    const section = document.getElementById(`round-section-${round}`);
    const toggle = document.getElementById(`toggle-${round}`);

    if (section && toggle) {
        if (toggle.checked) {
            section.classList.remove('hidden');
        } else {
            section.classList.add('hidden');
        }
    }
};

function startNewInterview() {
    // Clear previous data but keep student selected
    clearInterview(true);

    const activeScreen = document.getElementById('active-interview-screen');
    const mockScreen = document.getElementById('mock-interview-screen');

    // Switch Screens
    // Switch Screens using Navigation Stack
    navigateToScreen('active-interview-screen');

    // Scroll to top
    window.scrollTo(0, 0);
}

async function fetchStudentAndConfirm(pin) {
    const batchId = document.getElementById('interview-class-dropdown').value;
    const profileContainer = document.getElementById('interview-student-profile');
    const activeScreen = document.getElementById('active-interview-screen');

    // Hide active screen on fresh fetch (safety)
    // Actually, we are on profile screen, so active screen should be hidden anyway.
    if (activeScreen) activeScreen.classList.add('hidden');

    if (!batchId) {
        showToast('Please select a batch first', 'warning');
        return;
    }

    // 1. Find Student Details locally first (fastest)
    let student = null;
    if (AppState.batches[batchId] && AppState.batches[batchId].students) {
        const students = Object.values(AppState.batches[batchId].students);
        student = students.find(s => (s.pin || s.pinNumber) === pin);
    }

    if (!student) {
        // Try Firebase direct fetch if not found locally (optional, but good for large lists)
        profileContainer.classList.add('hidden');
        showToast('Student not found in this batch', 'error');
        return;
    }

    // 2. Render Student Profile
    document.getElementById('interview-name').textContent = student.name;
    document.getElementById('interview-branch').textContent = student.branch || 'N/A';
    document.getElementById('interview-combo').textContent = student.combo || 'N/A';
    document.getElementById('interview-avatar').textContent = student.name.charAt(0);

    profileContainer.classList.remove('hidden');

    // 3. Fetch History
    const historyList = document.getElementById('interview-history-list');
    historyList.innerHTML = '<div style="color: var(--text-muted); padding: 10px; text-align: center;"><i class="fas fa-spinner fa-spin"></i> Loading history...</div>';

    try {
        const historyData = await FirebaseService.fetchStudentMockInterviews(batchId, pin);
        // Add ID to record for reference if needed
        const history = Object.entries(historyData || {})
            .map(([key, val]) => ({ ...val, id: key }))
            .sort((a, b) => b.timestamp - a.timestamp);

        if (history.length === 0) {
            historyList.innerHTML = '<div style="color: var(--text-muted); padding: 10px; font-size: 0.85rem; text-align: center;">No previous interviews</div>';
        } else {
            historyList.innerHTML = history.map((record, index) => `
                <div class="history-item" onclick='viewInterviewDetails(${JSON.stringify(record).replace(/'/g, "&apos;")})'
                     style="background: rgba(255,255,255,0.05); padding: 10px; border-radius: 8px; display: flex; justify-content: space-between; align-items: center; cursor: pointer; transition: background 0.2s;">
                    <div>
                        <div style="font-size: 0.85rem; font-weight: 600;">${record.displayDate || new Date(record.timestamp).toLocaleDateString()}</div>
                        <div style="font-size: 0.75rem; color: var(--text-muted);">${record.interviewer || 'Unknown'}</div>
                    </div>
                    <div style="display: flex; align-items: center; gap: 5px;">
                        <span style="color: var(--techwing-orange); font-weight: 700;">${record.rating}</span>
                        <i class="fas fa-star" style="font-size: 0.7rem; color: var(--techwing-orange);"></i>
                        <i class="fas fa-chevron-right" style="font-size: 0.7rem; color: var(--text-muted); margin-left: 5px;"></i>
                    </div>
                </div>
            `).join('');
        }

    } catch (error) {
        console.error('Error fetching history:', error);
        historyList.innerHTML = '<div style="color: var(--error-color); padding: 10px; text-align: center;">Failed to load history</div>';
    }
}

// Deprecated but kept to prevent reference errors if called references exist
function updateStarRating() {
    // highlightStars(AppState.interviewRating);
}

function highlightStars(rating) {
    document.querySelectorAll('#overall-rating i').forEach(star => {
        const starRating = parseInt(star.dataset.rating);
        star.className = starRating <= rating ? 'fas fa-star' : 'far fa-star';
        star.style.color = starRating <= rating ? 'var(--techwing-orange)' : 'var(--text-muted)';
    });
}

async function saveInterview() {
    const studentPin = document.getElementById('interview-student-pin-input').value.trim();
    const notes = document.getElementById('interview-notes').value;
    const batchId = document.getElementById('interview-class-dropdown').value;
    const resumeScore = document.getElementById('resume-score-slider').value;

    if (!batchId) {
        showToast('Please select a batch', 'warning');
        return;
    }

    if (!studentPin) {
        showToast('Please enter student Roll Number/PIN', 'warning');
        return;
    }

    // Collect Round Data
    const rounds = {};
    let totalScore = 0;
    let activeSectionCount = 0;

    // Helper to collect metrics
    const collectRoundMetrics = (roundId, roundName) => {
        const section = document.getElementById(`round-section-${roundId}`);
        if (!section || section.classList.contains('hidden')) return null;

        const metrics = {};
        let roundTotal = 0;
        let metricCount = 0;

        section.querySelectorAll('.metric-slider').forEach(slider => {
            const label = slider.previousElementSibling.textContent;
            const value = parseFloat(slider.value);
            metrics[label] = value;
            roundTotal += value;
            metricCount++;
        });

        const average = metricCount > 0 ? (roundTotal / metricCount).toFixed(2) : 0;

        return {
            name: roundName,
            metrics: metrics,
            average: parseFloat(average)
        };
    };

    const trData = collectRoundMetrics('tr', 'Technical Round');
    if (trData) { rounds.TR = trData; activeSectionCount++; totalScore += trData.average; }

    const hrData = collectRoundMetrics('hr', 'HR Round');
    if (hrData) { rounds.HR = hrData; activeSectionCount++; totalScore += hrData.average; }

    const mrData = collectRoundMetrics('mr', 'Managerial Round');
    if (mrData) { rounds.MR = mrData; activeSectionCount++; totalScore += mrData.average; }

    if (activeSectionCount === 0) {
        showToast('Please select at least one round (TR, HR, or MR)', 'warning');
        return;
    }

    const saveBtn = document.getElementById('save-interview-btn');
    const originalText = saveBtn.innerHTML;
    saveBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Saving...';
    saveBtn.disabled = true;

    try {
        const interviewData = {
            resumeScore: parseFloat(resumeScore),
            rounds: rounds, // Detailed data
            rating: (totalScore / activeSectionCount).toFixed(1), // Overall Average for quick display
            notes: notes,
            timestamp: Date.now(),
            interviewer: AppState.currentUser ? AppState.currentUser.name : 'Unknown',
            displayDate: FirebaseService.getTodayDateFormatted()
        };

        if (typeof FirebaseService !== 'undefined') {
            await FirebaseService.saveMockInterview(batchId, studentPin, interviewData);
            showToast('Interview saved successfully!', 'success');
            clearInterview();

            // Navigate back to profile
            // Navigate back to profile
            navigateBack();

            // Refresh history if same student is still selected
            if (document.getElementById('interview-student-pin-input').value === studentPin) {
                fetchStudentAndConfirm(studentPin);
            }
        } else {
            showToast('Firebase not connected (Offline Mode)', 'warning');
        }
    } catch (error) {
        console.error('Save interview error:', error);
        showToast('Failed to save interview', 'error');
    } finally {
        saveBtn.innerHTML = originalText;
        saveBtn.disabled = false;
    }
}

function clearInterview(keepStudent = false) {
    if (!keepStudent) {
        document.getElementById('interview-student-pin-input').value = '';
        document.getElementById('interview-student-profile').classList.add('hidden');
    }
    document.getElementById('interview-notes').value = '';
    document.getElementById('resume-score-slider').value = 5;
    document.getElementById('resume-score-display').textContent = '5';

    // Reset Rounds
    ['tr', 'hr', 'mr'].forEach(round => {
        const section = document.getElementById(`round-section-${round}`);
        const toggle = document.getElementById(`toggle-${round}`);

        if (section) section.classList.add('hidden');
        if (toggle) toggle.checked = false;

        // Reset Sliders
        if (section) {
            section.querySelectorAll('.metric-slider').forEach(slider => {
                slider.value = 5;
                slider.nextElementSibling.textContent = '5';
            });
        }
    });
}

function updateStarRating() {
    // Deprecated but kept to prevent reference errors if called references exist
}

function highlightStars(rating) {
    // Deprecated
}

// ==========================================
// DASHBOARD SCREEN
// ==========================================
function initDashboardEvents() {
    // Note: Batch dropdown is initialized via initCustomDropdown in populateFirebaseDropdowns/populateAllDropdowns
    // The callback handles batch selection, no need for a change listener here

    // Tabs
    document.querySelectorAll('#dashboard-screen .tab-btn').forEach(btn => {
        btn.addEventListener('click', function () {
            document.querySelectorAll('#dashboard-screen .tab-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');
            renderAttendanceList(this.dataset.tab);
        });
    });

    // Search
    document.getElementById('student-search').addEventListener('input', function () {
        const activeTab = document.querySelector('#dashboard-screen .tab-btn.active').dataset.tab;
        renderAttendanceList(activeTab, this.value.toLowerCase());
    });

    // Sync button
    document.getElementById('manual-sync-btn').addEventListener('click', handleManualSync);

    // Export button
    document.getElementById('export-csv-btn').addEventListener('click', exportAttendanceCSV);
}

// Initialize Dashboard Session Toggle
function initDashboardSessionToggle() {
    const toggle = document.getElementById('dashboard-session-checkbox');
    if (!toggle) return;

    toggle.addEventListener('change', (e) => {
        // Unchecked = Morning, Checked = Afternoon
        const isPM = e.target.checked;
        AppState.sessionType = isPM ? 'afternoon' : 'morning';
        console.log('📅 Session changed to:', AppState.sessionType);

        // Update scanner screen display
        const scannerDisplay = document.getElementById('scanner-session-display');
        if (scannerDisplay) {
            scannerDisplay.textContent = AppState.sessionType === 'morning' ? 'Morning' : 'Afternoon';
        }

        // Sync with Valid Setup Screen Toggle if exists
        const setupToggle = document.getElementById('session-type-checkbox');
        if (setupToggle) {
            setupToggle.checked = isPM;
        }

        showToast(`Session: ${AppState.sessionType === 'morning' ? 'Morning (AM)' : 'Afternoon (PM)'}`, 'info');
        updateDashboard(); // Refresh dashboard data if needed
    });
}

// Initialize Session Setup Screen Events
function initSessionSetupScreenEvents() {
    // Session Type Toggle
    const sessionToggle = document.getElementById('session-type-checkbox');
    if (sessionToggle) {
        sessionToggle.addEventListener('change', (e) => {
            // Unchecked = Morning, Checked = Afternoon
            const isPM = e.target.checked;
            AppState.sessionType = isPM ? 'afternoon' : 'morning';
            console.log('📅 Session type selected:', AppState.sessionType);

            // Sync with Dashboard Toggle if exists
            const dashToggle = document.getElementById('dashboard-session-checkbox');
            if (dashToggle) {
                dashToggle.checked = isPM;
            }
        });
    }

    // Start Session Button
    const startBtn = document.getElementById('start-session-btn');
    if (startBtn) {
        startBtn.addEventListener('click', () => {
            const selectedBatch = document.getElementById('session-class-dropdown')?.value;

            if (!selectedBatch) {
                showToast('Please select a batch first', 'warning');
                return;
            }

            // Set the active class if using Firebase
            if (AppState.firebaseClasses) {
                const classData = AppState.firebaseClasses.find(c => c.id === selectedBatch);
                if (classData) {
                    AppState.activeClass = classData;
                }
            } else {
                selectClass(selectedBatch);
            }

            showToast(`Starting ${AppState.sessionType} session`, 'success');

            // Navigate to scanner screen
            showScreen('scanner-screen');
        });
    }

    // Home Screen Scan Button - Redirect to Session Setup
    const homeScanBtn = document.getElementById('scan-attendance-btn');
    if (homeScanBtn) {
        // Remove existing listeners by cloning
        const newBtn = homeScanBtn.cloneNode(true);
        homeScanBtn.parentNode.replaceChild(newBtn, homeScanBtn);

        newBtn.addEventListener('click', () => {
            console.log('🔘 Scan button clicked - Navigating to Session Setup');
            navigateToScreen('session-setup-screen');
        });
    }
    // Back button
    const backBtn = document.getElementById('session-back-btn');
    if (backBtn) {
        backBtn.addEventListener('click', () => {
            navigateBack();
        });
    }
}

// Call session toggle init on app load
document.addEventListener('DOMContentLoaded', () => {
    setTimeout(() => {
        initDashboardSessionToggle();
        initSessionSetupScreenEvents();
    }, 100);
});

function updateDashboardDate() {
    const today = new Date();
    document.getElementById('dashboard-date').textContent = today.toLocaleDateString('en-US', {
        weekday: 'short',
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

function updateDashboard() {
    if (!AppState.activeClass) return;

    document.getElementById('dashboard-class-dropdown').value = AppState.activeClass.id;

    // Get students from active class
    const students = AppState.activeClass.students || [];

    // Get present pins from attendance records
    const records = AppState.attendanceRecords;
    const presentPins = new Set(records.filter(r => r.status === 'present').map(r => r.pinNumber));

    // Calculate stats
    const studentPins = new Set(students.map(s => s.pin || s.pinNumber));
    const presentCount = records.filter(r => r.status === 'present' && studentPins.has(r.pinNumber)).length;
    const totalCount = students.length;
    const absentCount = totalCount - presentCount;

    // Update display
    document.getElementById('present-count').textContent = presentCount;
    document.getElementById('absent-count').textContent = absentCount;
    document.getElementById('total-count').textContent = totalCount;
    document.getElementById('pending-count').textContent = AppState.syncPending;

    // Update progress bars
    const presentPercent = totalCount > 0 ? Math.round((presentCount / totalCount) * 100) : 0;
    const absentPercent = totalCount > 0 ? Math.round((absentCount / totalCount) * 100) : 0;

    document.getElementById('present-percent').textContent = `${presentPercent}%`;
    document.getElementById('absent-percent').textContent = `${absentPercent}%`;
    document.getElementById('present-progress').style.width = `${presentPercent}%`;
    document.getElementById('absent-progress').style.width = `${absentPercent}%`;

    renderAttendanceList('present');
}

function renderAttendanceList(tab, searchQuery = '') {
    if (!AppState.activeClass) return;

    const container = document.getElementById('attendance-list');
    const records = AppState.attendanceRecords;
    const presentPins = new Set(records.filter(r => r.status === 'present').map(r => r.pinNumber));

    // Start with all students
    let students = [...(AppState.activeClass.students || [])];

    // Apply tab filter (handle both pin and pinNumber)
    if (tab === 'present') {
        students = students.filter(s => presentPins.has(s.pin || s.pinNumber));
    } else if (tab === 'absent') {
        students = students.filter(s => !presentPins.has(s.pin || s.pinNumber));
    }

    // Apply search filter
    if (searchQuery) {
        students = students.filter(s =>
            s.name.toLowerCase().includes(searchQuery) ||
            (s.pin || s.pinNumber || '').toLowerCase().includes(searchQuery)
        );
    }

    if (students.length === 0) {
        container.innerHTML = `<div style="text-align: center; padding: 40px; color: var(--text-secondary);">No students found</div>`;
        return;
    }

    container.innerHTML = students.map(student => {
        const pin = student.pin || student.pinNumber;
        const isPresent = presentPins.has(pin);
        const record = records.find(r => r.pinNumber === pin);
        return `
            <div class="student-item" onclick="showStudentDetails('${pin}')">
                <div class="student-avatar">${student.name.charAt(0)}</div>
                <div class="student-info">
                    <div class="student-name">${student.name}</div>
                    <div class="student-pin">${pin} • ${student.branch || 'N/A'}</div>
                </div>
                <span class="student-status ${isPresent ? 'present' : 'absent'}">
                    ${isPresent ? formatTime(record?.timestamp) : 'Absent'}
                </span>
            </div>
        `;
    }).join('');
}

function handleManualSync() {
    const syncBtn = document.getElementById('manual-sync-btn');
    const progressDiv = document.getElementById('sync-progress');
    const progressFill = document.getElementById('progress-fill');
    const progressText = document.getElementById('progress-text');

    syncBtn.disabled = true;
    progressDiv.classList.remove('hidden');

    let progress = 0;
    const interval = setInterval(() => {
        progress += 10;
        progressFill.style.width = `${progress}%`;
        progressText.textContent = `Syncing... ${progress}%`;

        if (progress >= 100) {
            clearInterval(interval);
            AppState.attendanceRecords.forEach(r => r.synced = true);
            AppState.syncPending = 0;

            document.getElementById('pending-count').textContent = '0';
            document.getElementById('last-sync-time').textContent = formatDateTime(new Date());
            progressText.textContent = 'Sync complete!';

            setTimeout(() => {
                progressDiv.classList.add('hidden');
                syncBtn.disabled = false;
                progressFill.style.width = '0%';
            }, 1500);

            showToast('Attendance synced successfully!', 'success');
        }
    }, 200);
}

function exportAttendanceCSV() {
    if (!AppState.activeClass) {
        showToast('No batch selected', 'warning');
        return;
    }

    const records = AppState.attendanceRecords;
    const presentPins = new Set(records.filter(r => r.status === 'present').map(r => r.pinNumber));

    let csv = 'PIN Number,Name,Branch,Combo,Status,Time\n';

    AppState.activeClass.students.forEach(student => {
        const isPresent = presentPins.has(student.pinNumber);
        const record = records.find(r => r.pinNumber === student.pinNumber);
        const time = record ? formatTime(record.timestamp) : '-';
        csv += `${student.pinNumber},${student.name},${student.branch},${student.combo},${isPresent ? 'Present' : 'Absent'},${time}\n`;
    });

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `attendance_${AppState.activeClass.classCode}_${AppState.sessionDate}.csv`;
    a.click();
    URL.revokeObjectURL(url);

    showToast('CSV exported successfully!', 'success');
}

// ==========================================
// SETTINGS SCREEN
// ==========================================
function initSettingsEvents() {
    document.getElementById('batch-dropdown').addEventListener('change', function () {
        updateSettingsClassList();
    });

    // Student Search Input
    document.getElementById('student-search-input').addEventListener('input', function () {
        performStudentSearch(this.value);
    });

    document.getElementById('search-btn').addEventListener('click', function () {
        performStudentSearch();
    });

    document.getElementById('sync-batch-btn').addEventListener('click', function () {
        showToast('Syncing all batches...', 'info');
        setTimeout(() => showToast('All batches synced!', 'success'), 2000);
    });

    document.getElementById('logout-btn').addEventListener('click', handleLogout);
}

function updateSettingsClassList() {
    const container = document.getElementById('settings-class-list');
    const selectedBatch = document.getElementById('batch-dropdown').value;

    let classes = AppState.firebaseClasses || mockData.classes;
    if (selectedBatch) {
        classes = classes.filter(c => c.batchId === selectedBatch);
    }

    if (classes.length === 0) {
        container.innerHTML = `<div style="text-align: center; padding: 20px; color: var(--text-secondary);">No batches found</div>`;
        return;
    }

    container.innerHTML = classes.map(classData => {
        const showDelete = AppState.userRole === 'admin';
        return `
        <div class="class-item">
            <div>
                <div class="class-name">${classData.className}</div>
                <div class="class-meta">${classData.students.length} students • Last sync: ${classData.lastSyncTime || 'Never'}</div>
            </div>
            <div class="class-actions">
                <button class="icon-btn" onclick="syncClass('${classData.id}')" title="Sync">
                    <i class="fas fa-sync"></i>
                </button>
                ${showDelete ? `<button class="icon-btn danger" onclick="deleteClass('${classData.id}')" title="Delete">
                    <i class="fas fa-trash"></i>
                </button>` : ''}
            </div>
        </div>
    `}).join('');
}

function syncClass(classId) {
    showToast('Syncing batch...', 'info');
    setTimeout(() => showToast('Batch synced!', 'success'), 1500);
}

async function deleteClass(classId) {
    // Admin guard
    if (AppState.userRole !== 'admin') {
        showToast('Admin access required to delete batches', 'warning');
        return;
    }

    if (confirm('Are you sure you want to delete this batch? This action cannot be undone.')) {
        try {
            if (typeof FirebaseService !== 'undefined') {
                await FirebaseService.deleteBatch(classId);
                showToast('Batch deleted successfully', 'success');

                // Refresh App Data
                initializeAppData();
            } else {
                showToast('Cannot delete in offline mode', 'warning');
            }
        } catch (error) {
            console.error('Delete batch error:', error);
            showToast('Failed to delete batch', 'error');
        }
    }
}

function handleLogout() {
    if (confirm('Are you sure you want to logout?')) {
        localStorage.removeItem('techwing_user');
        AppState.isLoggedIn = false;
        AppState.currentUser = null;
        AppState.userRole = 'user';

        document.getElementById('main-app').classList.add('hidden');
        document.getElementById('login-screen').classList.add('active');
        document.getElementById('username').value = '';
        document.getElementById('password').value = '';

        showToast('Logged out successfully', 'success');
    }
}

// ==========================================
// MANAGEMENT & ADMIN FEATURES
// ==========================================
function initManagementEvents() {
    // --- BATCH MANAGEMENT ---
    const addBatchBtn = document.getElementById('add-batch-btn');
    const addBatchModal = document.getElementById('add-batch-modal');
    const cancelBatchBtn = document.getElementById('cancel-batch-btn');
    const saveBatchBtn = document.getElementById('save-batch-btn');

    if (addBatchBtn) {
        addBatchBtn.addEventListener('click', () => {
            addBatchModal.classList.remove('hidden');
        });
    }

    if (cancelBatchBtn) {
        cancelBatchBtn.addEventListener('click', () => {
            addBatchModal.classList.add('hidden');
        });
    }

    if (saveBatchBtn) {
        saveBatchBtn.addEventListener('click', async () => {
            const id = document.getElementById('new-batch-id').value.trim();
            const name = document.getElementById('new-batch-name').value.trim();

            if (!id || !name) {
                showToast('Please fill all fields', 'warning');
                return;
            }

            const originalText = saveBatchBtn.innerHTML;
            saveBatchBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Creating...';
            saveBatchBtn.disabled = true;

            try {
                const batchData = {
                    id: id,
                    name: name,
                    createdAt: Date.now()
                };

                await FirebaseService.addBatch(batchData);
                showToast('Batch created successfully!', 'success');
                addBatchModal.classList.add('hidden');

                // Refresh App Data
                initializeAppData();
            } catch (error) {
                console.error('Create batch error:', error);
                showToast('Failed to create batch', 'error');
            } finally {
                saveBatchBtn.innerHTML = originalText;
                saveBatchBtn.disabled = false;
            }
        });
    }

    // --- STUDENT MANAGEMENT ---
    const addStudentBtn = document.getElementById('add-student-btn');
    const addStudentModal = document.getElementById('add-student-modal');
    const cancelStudentBtn = document.getElementById('cancel-student-btn');
    const saveStudentBtn = document.getElementById('save-student-btn');

    if (addStudentBtn) {
        addStudentBtn.addEventListener('click', () => {
            // Ensure we are in a valid batch context
            if (!AppState.activeClass) {
                showToast('Please select a batch first', 'warning');
                return;
            }
            addStudentModal.classList.remove('hidden');
        });
    }

    if (cancelStudentBtn) {
        cancelStudentBtn.addEventListener('click', () => {
            addStudentModal.classList.add('hidden');
        });
    }

    if (saveStudentBtn) {
        saveStudentBtn.addEventListener('click', async () => {
            if (!AppState.activeClass) return;

            const name = document.getElementById('new-student-name').value.trim();
            const pin = document.getElementById('new-student-pin').value.trim();
            const phone = document.getElementById('new-student-phone').value.trim();
            const email = document.getElementById('new-student-email').value.trim();
            const branch = document.getElementById('new-student-branch').value.trim();
            const combo = document.getElementById('new-student-combo').value.trim();

            if (!name || !pin) {
                showToast('Name and PIN are required', 'warning');
                return;
            }

            const originalText = saveStudentBtn.innerHTML;
            saveStudentBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Adding...';
            saveStudentBtn.disabled = true;

            try {
                const studentData = {
                    name: name,
                    pinNumber: pin,
                    phone: phone,
                    email: email,
                    branch: branch,
                    combo: combo,
                    addedAt: Date.now()
                };

                await FirebaseService.addStudent(AppState.activeClass.id, studentData);
                showToast('Student added successfully!', 'success');
                addStudentModal.classList.add('hidden');

                // Refresh Student List
                // We could re-fetch whole app data, but that's heavy. 
                // Let's manually add to local state and re-render for speed, 
                // OR re-fetch just this batch's students.

                // Option A: Quick re-fetch of students for this batch
                const students = await FirebaseService.fetchStudents(AppState.activeClass.id);
                AppState.activeClass.students = Object.values(students || {});

                // Update global batch list reference too if needed
                if (AppState.batches[AppState.activeClass.id]) {
                    AppState.batches[AppState.activeClass.id].students = students;
                }

                // Re-render
                renderBatchOverview();

            } catch (error) {
                console.error('Add student error:', error);
                showToast('Failed to add student', 'error');
        });
    }

    // Excel template & upload registration
    initExcelImportActions();
}

let pendingImportData = null; // Stores parsed BTech roster data during confirmation

function initExcelImportActions() {
    const downloadTemplateBtn = document.getElementById('download-template-btn');
    const importExcelBtn = document.getElementById('import-excel-btn');
    const excelFileInput = document.getElementById('excel-file-input');
    const cancelImportBtn = document.getElementById('cancel-import-btn');
    const confirmImportBtn = document.getElementById('confirm-import-btn');

    if (downloadTemplateBtn) {
        downloadTemplateBtn.addEventListener('click', () => {
            try {
                if (typeof XLSX === 'undefined') {
                    showToast('Excel library not loaded. Please reload.', 'error');
                    return;
                }
                const wb = XLSX.utils.book_new();
                const branches = ['CSE', 'ECE', 'EEE', 'MECH'];
                const headers = [
                    ["Name", "Pin-number", "Branch", "Mail-id", "Mobile Number", "Tech Course", "Section", "Sec-Codes"]
                ];
                
                // Pre-fill realistic sample rows matching requested BTech courses
                const demoRows = {
                    'CSE': ["Arun Kumar", "24991A0501", "CSE", "arun.kumar_1@techwing.edu", "9876543210", "AWS + DEVOPS", "A", "SC87F3A9"],
                    'ECE': ["Priya Sharma", "24991A0401", "ECE", "priya.sharma_1@techwing.edu", "9876543211", "JFS + UIUX", "A", "SC92B4D7"],
                    'EEE': ["Ravi Reddy", "24991A0201", "EEE", "ravi.reddy_1@techwing.edu", "9876543212", "AWS + GENAI", "A", "SC39C2E8"],
                    'MECH': ["Sneha Naidu", "24991A0301", "MECH", "sneha.naidu_1@techwing.edu", "9876543213", "JFS + DEVOPS", "A", "SC48D1F7"]
                };
                
                branches.forEach(branch => {
                    const wsData = [
                        ...headers,
                        demoRows[branch]
                    ];
                    const ws = XLSX.utils.aoa_to_sheet(wsData);
                    ws['!cols'] = [
                        { wch: 25 }, // Name
                        { wch: 15 }, // PIN
                        { wch: 10 }, // Branch
                        { wch: 28 }, // Email
                        { wch: 15 }, // Phone
                        { wch: 20 }, // Course
                        { wch: 10 }, // Section
                        { wch: 12 }  // Sec-Codes
                    ];
                    XLSX.utils.book_append_sheet(wb, ws, branch);
                });
                
                XLSX.writeFile(wb, "BTech_Attendance_Template.xlsx");
                showToast('Template downloaded successfully!', 'success');
            } catch (err) {
                console.error(err);
                showToast('Error generating template', 'error');
            }
        });
    }

    if (importExcelBtn && excelFileInput) {
        importExcelBtn.addEventListener('click', () => {
            // Must have admin role
            if (AppState.userRole !== 'admin') {
                showToast('Admin access required to import rosters', 'error');
                return;
            }
            // Must have a batch selected in the dropdown
            const activeBatchId = document.getElementById('batch-dropdown').value;
            if (!activeBatchId) {
                showToast('Please select a Year/Batch first from the dropdown', 'warning');
                return;
            }
            excelFileInput.click();
        });

        excelFileInput.addEventListener('change', handleExcelUpload);
    }

    if (cancelImportBtn) {
        cancelImportBtn.addEventListener('click', () => {
            document.getElementById('import-confirm-modal').classList.add('hidden');
            excelFileInput.value = '';
            pendingImportData = null;
        });
    }

    if (confirmImportBtn) {
        confirmImportBtn.addEventListener('click', async () => {
            if (!pendingImportData) return;

            const originalText = confirmImportBtn.innerHTML;
            confirmImportBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Importing...';
            confirmImportBtn.disabled = true;

            try {
                const batchId = pendingImportData.batchId;
                const year = pendingImportData.year;
                const data = pendingImportData.data;

                // Import each branch tab into Firebase
                for (const branch in data) {
                    const targetBatchId = `${year}_${branch.toLowerCase()}`;
                    
                    const studentsMap = {};
                    data[branch].forEach(student => {
                        studentsMap[student.pin] = student;
                    });

                    // Set batch registry entry
                    const batchMetadata = {
                        id: targetBatchId,
                        year: parseInt(year),
                        branch: branch,
                        sheetTabName: branch,
                        name: `${branch} Section (${year} Batch)`
                    };
                    await FirebaseService.database.ref(`/batches/${targetBatchId}`).set(batchMetadata);

                    // Write to /students/{batchId} node
                    await FirebaseService.database.ref(`/students/${targetBatchId}`).set(studentsMap);
                }

                showToast('Import completed successfully!', 'success');
                document.getElementById('import-confirm-modal').classList.add('hidden');
                
                // Reload UI states
                initializeAppData();
            } catch (err) {
                console.error(err);
                showToast('Import failed. Check network connection.', 'error');
            } finally {
                confirmImportBtn.innerHTML = originalText;
                confirmImportBtn.disabled = false;
                excelFileInput.value = '';
                pendingImportData = null;
            }
        });
    }
}

function handleExcelUpload(e) {
    const file = e.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = function (evt) {
        try {
            const data = evt.target.result;
            const workbook = XLSX.read(data, { type: 'binary' });

            const parsedBranches = {};
            const branches = ['CSE', 'ECE', 'EEE', 'MECH'];
            let totalStudents = 0;
            let hasValidSheet = false;

            workbook.SheetNames.forEach(sheetName => {
                const upperSheetName = sheetName.toUpperCase().trim();
                if (branches.includes(upperSheetName)) {
                    const sheet = workbook.Sheets[sheetName];
                    const rows = XLSX.utils.sheet_to_json(sheet);

                    if (rows.length > 0) {
                        const parsedStudents = [];
                        rows.forEach((row, idx) => {
                            const sName = row["Name"] || row["student name"];
                            const sPin = row["Pin-number"] || row["Pin"] || row["Roll Number"] || row["Pin Number"];
                            const sBranch = row["Branch"] || upperSheetName;
                            const sEmail = row["Mail-id"] || row["Email"] || row["Mail"];
                            const sPhone = row["Mobile Number"] || row["Phone"] || row["Mobile"];
                            const sCourse = row["Tech Course"] || row["Course"] || row["Combo"];
                            const sSec = row["Section"] || row["Sec"];
                            const sCode = row["Sec-Codes"] || row["Sec-Code"] || row["Security Code"] || row["Security Codes"];

                            if (sName && sPin) {
                                parsedStudents.push({
                                    name: String(sName).trim(),
                                    pinNumber: String(sPin).trim(),
                                    pin: String(sPin).trim(),
                                    branch: String(sBranch).trim().toUpperCase(),
                                    email: sEmail ? String(sEmail).trim() : "",
                                    phone: sPhone ? String(sPhone).trim() : "",
                                    combo: sCourse ? String(sCourse).trim() : "AWS + DEVOPS",
                                    section: sSec ? String(sSec).trim().toUpperCase() : "A",
                                    secCode: sCode ? String(sCode).trim() : ""
                                });
                            }
                        });

                        if (parsedStudents.length > 0) {
                            parsedBranches[upperSheetName] = parsedStudents;
                            totalStudents += parsedStudents.length;
                            hasValidSheet = true;
                        }
                    }
                }
            });

            if (!hasValidSheet) {
                showToast('No BTech branch sheets (CSE, ECE, EEE, MECH) found in template format.', 'error');
                document.getElementById('excel-file-input').value = '';
                return;
            }

            showImportConfirmation(parsedBranches, totalStudents);

        } catch (err) {
            console.error(err);
            showToast('Error reading file. Ensure it is a valid Excel spreadsheet.', 'error');
            document.getElementById('excel-file-input').value = '';
        }
    };
    reader.readAsBinaryString(file);
}

function showImportConfirmation(parsedBranches, totalStudents) {
    const activeBatchId = document.getElementById('batch-dropdown').value;
    const selectedBatchObj = AppState.batches[activeBatchId];
    const batchName = selectedBatchObj ? selectedBatchObj.name : activeBatchId;

    pendingImportData = {
        batchId: activeBatchId,
        year: selectedBatchObj ? (selectedBatchObj.year || batchName.match(/\d{4}/)?.[0] || '2024') : '2024',
        data: parsedBranches
    };

    const summaryContainer = document.getElementById('import-summary-container');
    summaryContainer.innerHTML = `
        <p>You are importing BTech student rosters into: <strong style="color: var(--techwing-cyan);">${batchName}</strong>.</p>
        <p>This will write roster data directly to Firebase, replacing any existing branch records for this batch year.</p>
        <p>Total students parsed: <strong>${totalStudents}</strong></p>
    `;

    const tableBody = document.getElementById('import-details-table-body');
    tableBody.innerHTML = '';

    Object.keys(parsedBranches).forEach(branch => {
        const count = parsedBranches[branch].length;
        const row = document.createElement('tr');
        row.style.borderBottom = '1px solid var(--border-color)';
        row.innerHTML = `
            <td style="padding: 10px; color: var(--text-primary); font-weight: 500;">${branch}</td>
            <td style="padding: 10px; text-align: center; color: var(--text-secondary);">${count}</td>
            <td style="padding: 10px; text-align: center; color: var(--techwing-green); font-weight: 600;">
                <i class="fas fa-check-circle"></i> Ready
            </td>
        `;
        tableBody.appendChild(row);
    });

    document.getElementById('import-confirm-modal').classList.remove('hidden');
}

// ==========================================
// UTILITIES
// ==========================================
function formatTime(isoString) {
    const date = new Date(isoString);
    return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
}

function formatDateTime(date) {
    return date.toLocaleString('en-US', {
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');

    const icons = {
        success: 'fa-check-circle',
        error: 'fa-times-circle',
        warning: 'fa-exclamation-triangle',
        info: 'fa-info-circle'
    };

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <i class="fas ${icons[type]} toast-icon"></i>
        <span class="toast-message">${message}</span>
        <button class="toast-close" onclick="this.parentElement.remove()">
            <i class="fas fa-times"></i>
        </button>
    `;

    container.appendChild(toast);

    setTimeout(() => {
        toast.style.animation = 'slideIn 0.3s ease reverse';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// ==========================================
// CUSTOM DROPDOWN HANDLERS (Portal Structure)
// ==========================================
function initCustomDropdown(wrapperId, portalId, options, onChange) {
    console.log(`🔽 initCustomDropdown called: ${wrapperId}`);

    const wrapper = document.getElementById(wrapperId);
    const portal = document.getElementById(portalId);

    if (!wrapper) {
        console.error(`❌ Wrapper not found: ${wrapperId}`);
        return;
    }
    if (!portal) {
        console.error(`❌ Portal not found: ${portalId}`);
        return;
    }

    const trigger = wrapper.querySelector('.dropdown-trigger');
    const menu = portal.querySelector('.dropdown-menu');
    const textSpan = wrapper.querySelector('.dropdown-text');
    const hiddenInput = wrapper.querySelector('input[type="hidden"]');

    if (!trigger) {
        console.error(`❌ Trigger button not found in ${wrapperId}`);
        return;
    }
    if (!menu) {
        console.error(`❌ Menu not found in ${portalId}`);
        return;
    }

    console.log(`✅ Found elements for ${wrapperId}, adding ${options.length} options`);

    // Remove existing event listeners by cloning
    const newTrigger = trigger.cloneNode(true);
    trigger.parentNode.replaceChild(newTrigger, trigger);

    const newMenu = menu.cloneNode(false); // Clone without children (we refill them anyway)
    menu.parentNode.replaceChild(newMenu, menu);

    // Populate options
    newMenu.innerHTML = options.map(opt => `
        <button class="dropdown-option" data-value="${opt.value}">
            ${opt.label}
        </button>
    `).join('');

    // Toggle dropdown - toggle open class on PORTAL
    newTrigger.addEventListener('click', (e) => {
        console.log(`🔽 Dropdown clicked: ${wrapperId}`);
        e.stopPropagation();
        e.preventDefault();

        // Calculate position
        const rect = newTrigger.getBoundingClientRect();
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
        const scrollLeft = window.pageXOffset || document.documentElement.scrollLeft;

        portal.style.top = `${rect.bottom + scrollTop + 8}px`; // 8px spacing
        portal.style.left = `${rect.left + scrollLeft}px`;
        portal.style.width = `${rect.width}px`;

        portal.classList.toggle('open');
        wrapper.classList.toggle('open');
    });

    // Handle option selection
    newMenu.addEventListener('click', (e) => {
        const option = e.target.closest('.dropdown-option');
        if (option) {
            const value = option.dataset.value;
            const label = option.textContent.trim();

            // Update UI
            const currentTextSpan = wrapper.querySelector('.dropdown-text');
            const currentHiddenInput = wrapper.querySelector('input[type="hidden"]');
            if (currentTextSpan) currentTextSpan.textContent = label;
            if (currentHiddenInput) currentHiddenInput.value = value;

            // Update selected state
            newMenu.querySelectorAll('.dropdown-option').forEach(o => o.classList.remove('selected'));
            option.classList.add('selected');

            // Close dropdown
            portal.classList.remove('open');
            wrapper.classList.remove('open');

            // Callback
            if (onChange) onChange(value, label);
        }
    });

    // Close on outside click
    document.addEventListener('click', (e) => {
        if (!wrapper.contains(e.target) && !portal.contains(e.target)) {
            portal.classList.remove('open');
            wrapper.classList.remove('open');
        }
    });

    // Close on resize/scroll to avoid floating dropdowns
    window.addEventListener('resize', () => {
        if (portal.classList.contains('open')) {
            portal.classList.remove('open');
            wrapper.classList.remove('open');
        }
    });

    window.addEventListener('scroll', () => {
        if (portal.classList.contains('open')) {
            // Optional: update position instead of closing
            // For simplicity, we close it
            portal.classList.remove('open');
            wrapper.classList.remove('open');
        }
    }, true); // Capture phase for scrolling elements
}

// Initialize Dashboard Class Dropdown
function initDashboardClassDropdown() {
    const classes = AppState.firebaseClasses || mockData.classes;
    const options = classes.map(c => ({
        value: c.id,
        label: `${c.className} (${c.classCode})`
    }));

    // Add placeholder option
    options.unshift({ value: '', label: 'Select a batch...' });

    // Now passing both wrapper ID and portal ID
    initCustomDropdown('dashboard-class-dropdown-wrapper', 'dashboard-class-menu-portal', options, (value, label) => {
        if (value) {
            const classes = AppState.firebaseClasses || mockData.classes;
            AppState.activeClass = classes.find(c => c.id === value);
            updateDashboard();
            showToast(`Loaded ${label}`, 'success');
        }
    });
}

// ==========================================
// LOADING SCREEN ANIMATION
// ==========================================
function simulateLoading() {
    const loader = document.getElementById('loading-screen');
    const progressBar = document.querySelector('.loader-progress-fill');
    const texts = ['SYSTEM INITIALIZING...', 'CONNECTING TO SERVER...', 'LOADING ASSETS...', 'READY'];
    const textElement = document.querySelector('.loader-text');

    if (loader && progressBar) {
        // Reset
        progressBar.style.width = '0%';

        // Animate Progress & Text
        setTimeout(() => {
            progressBar.style.width = '30%';
            if (textElement) textElement.textContent = texts[1];
        }, 400);

        setTimeout(() => {
            progressBar.style.width = '70%';
            if (textElement) textElement.textContent = texts[2];
        }, 800);

        setTimeout(() => {
            progressBar.style.width = '100%';
            if (textElement) textElement.textContent = texts[3];
        }, 1400);

        // Hide
        setTimeout(() => {
            loader.classList.add('fade-out');
            setTimeout(() => {
                loader.style.display = 'none';
            }, 800); // Matches CSS transition
        }, 1800);
    }
}


// ==========================================
// ASYNC LOADING SCREEN ANIMATION (Typewriter)
// ==========================================
async function simulateLoadingAsync() {
    const loader = document.getElementById('loading-screen');
    const progressBar = document.querySelector('.loader-progress-fill');
    const textElement = document.querySelector('.loader-text');

    if (!loader || !progressBar || !textElement) return;

    // Helper for typewriter effect
    const typeText = (text) => {
        return new Promise(resolve => {
            textElement.textContent = '';
            let i = 0;
            const speed = 30;
            function type() {
                if (i < text.length) {
                    textElement.textContent += text.charAt(i);
                    i++;
                    setTimeout(type, 20 + Math.random() * 30);
                } else {
                    setTimeout(resolve, 100);
                }
            }
            type();
        });
    };

    const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));

    // Initial State
    progressBar.style.width = '5%';

    // "SYSTEM INITIALIZING..." is in HTML
    await wait(800);

    // Step 1: Connecting
    progressBar.style.width = '40%';
    await typeText('CONNECTING TO SERVER...');
    await wait(200);

    // Step 2: Assets
    progressBar.style.width = '75%';
    await typeText('DECRYPTING USER DATA...');
    await wait(250);

    // Step 3: Ready
    progressBar.style.width = '100%';
    await typeText('SYSTEM READY_');
    await wait(500);

    // Fade Out
    loader.classList.add('fade-out');
    await wait(800); // Matches CSS transition time
    loader.style.display = 'none';
}// ==========================================
// ASYNC LOADING SCREEN ANIMATION (Sci-Fi Scramble)
// ==========================================
async function simulateLoadingSciFi() {
    const loader = document.getElementById('loading-screen');
    const progressBar = document.querySelector('.loader-progress-fill');
    const textElement = document.querySelector('.loader-text');

    if (!loader || !progressBar || !textElement) return;

    const wait = (ms) => new Promise(resolve => setTimeout(resolve, ms));

    // Scramble Effect Helper
    const scrambleText = (finalText) => {
        return new Promise(resolve => {
            let iteration = 0;
            const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@#$%^&*';
            const originalText = finalText;

            const interval = setInterval(() => {
                textElement.innerText = originalText
                    .split('')
                    .map((letter, index) => {
                        if (index < iteration) {
                            return originalText[index];
                        }
                        return chars[Math.floor(Math.random() * chars.length)];
                    })
                    .join('');

                if (iteration >= originalText.length) {
                    clearInterval(interval);
                    resolve();
                }

                iteration += 1 / 2;
            }, 30);
        });
    };

    // Initial State
    progressBar.style.width = '5%';
    textElement.innerText = '';

    await wait(800);

    // Step 1: Connecting
    progressBar.style.width = '45%';
    await scrambleText('ESTABLISHING UPLINK...');
    await wait(400);

    // Step 2: Assets
    progressBar.style.width = '80%';
    await scrambleText('DECRYPTING SECURE DATA...');
    await wait(400);

    // Step 3: Ready
    progressBar.style.width = '100%';
    await scrambleText('ACCESS GRANTED');
    await wait(600);

    // Fade Out
    loader.classList.add('fade-out');
    await wait(800);
    loader.style.display = 'none';
}
