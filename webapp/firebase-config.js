/**
 * TechWing LMS - Firebase Configuration
 * 
 * SETUP:
 * 1. Go to Firebase Console: https://console.firebase.google.com
 * 2. Create/Select your project
 * 3. Go to Project Settings > General
 * 4. Scroll to "Your apps" > Web app
 * 5. Copy the firebaseConfig values below
 */

const firebaseConfig = {
    apiKey: "AIzaSyBHjFckzjq2X6Gx__6vbAtpxotPnETwK1g",
    authDomain: "tw-attendance.firebaseapp.com",
    databaseURL: "https://tw-attendance-default-rtdb.firebaseio.com",
    projectId: "tw-attendance",
    storageBucket: "tw-attendance.firebasestorage.app",
    messagingSenderId: "281067747520",
    appId: "1:281067747520:web:4b729a36fb5a155c605525"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);

// Get references
const auth = firebase.auth();
const database = firebase.database();

// ==========================================
// AUTH HELPERS
// ==========================================

/**
 * Sign in with username (auto-appends @gmail.com)
 * Uses Email/Password authentication
 */
async function signInWithUsername(username, password) {
    const email = `${username.toLowerCase().trim()}@gmail.com`;

    try {
        const userCredential = await auth.signInWithEmailAndPassword(email, password);
        console.log('✅ Signed in:', userCredential.user.email);
        return userCredential.user;
    } catch (error) {
        if (error.code === 'auth/user-not-found') {
            // First time login - create account
            try {
                const newUser = await auth.createUserWithEmailAndPassword(email, password);
                console.log('✅ Created new user:', newUser.user.email);
                return newUser.user;
            } catch (createError) {
                console.error('❌ Create user error:', createError);
                throw createError;
            }
        }
        console.error('❌ Sign in error:', error);
        throw error;
    }
}

/**
 * Sign out current user
 */
async function signOut() {
    try {
        await auth.signOut();
        console.log('✅ Signed out');
    } catch (error) {
        console.error('❌ Sign out error:', error);
        throw error;
    }
}

/**
 * Get current user
 */
function getCurrentUser() {
    return auth.currentUser;
}

// ==========================================
// DATABASE HELPERS
// ==========================================

/**
 * Fetch all batches
 */
async function fetchBatches() {
    const snapshot = await database.ref('/batches').once('value');
    return snapshot.val() || {};
}

/**
 * Fetch students for a batch
 */
async function fetchStudents(batchId) {
    const snapshot = await database.ref(`/students/${batchId}`).once('value');
    return snapshot.val() || {};
}

/**
 * Fetch attendance for a batch and date
 */
async function fetchAttendance(batchId, date) {
    const snapshot = await database.ref(`/attendance/${batchId}/${date}`).once('value');
    return snapshot.val() || {};
}

/**
 * Fetch full attendance history for a batch
 */
async function fetchBatchAttendanceHistory(batchId) {
    const snapshot = await database.ref(`/attendance/${batchId}`).once('value');
    return snapshot.val() || {};
}

/**
 * Mark attendance for a student
 */
async function markAttendance(batchId, date, pin, scanData) {
    const ref = database.ref(`/attendance/${batchId}/${date}/${pin}/scans`);
    await ref.push(scanData);
    console.log(`✅ Marked attendance for ${pin} on ${date}`);
}

/**
 * Get today's date in DD-MM-YY format
 */
function getTodayDateFormatted() {
    const now = new Date();
    const dd = String(now.getDate()).padStart(2, '0');
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const yy = String(now.getFullYear()).slice(-2);
    return `${dd}-${mm}-${yy}`;
}

/**
 * Listen for real-time attendance updates
 */
function listenToAttendance(batchId, date, callback) {
    const ref = database.ref(`/attendance/${batchId}/${date}`);
    ref.on('value', (snapshot) => {
        callback(snapshot.val() || {});
    });
    // Return unsubscribe function
    return () => ref.off('value');
}

/**
 * Add a new batch
 */
async function addBatch(batchData) {
    const batchId = batchData.id || `Batch_${Date.now()}`;
    await database.ref(`/batches/${batchId}`).set(batchData);
    console.log(`✅ Added batch: ${batchId}`);
    return batchId;
}

/**
 * Delete a batch
 */
async function deleteBatch(batchId) {
    await database.ref(`/batches/${batchId}`).remove();
    // Optional: Delete students and attendance for this batch?
    // For now, let's keep it simple and just remove the batch reference.
    console.log(`✅ Deleted batch: ${batchId}`);
}

/**
 * Add a student to a batch
 */
async function addStudent(batchId, studentData) {
    // Ensure we don't overwrite existing if not intended, but typically pin is unique key
    await database.ref(`/students/${batchId}/${studentData.pinNumber}`).set(studentData);
    console.log(`✅ Added student: ${studentData.name} to ${batchId}`);
}

/**
 * Delete a student from a batch
 */
async function deleteStudent(batchId, studentPin) {
    await database.ref(`/students/${batchId}/${studentPin}`).remove();
    console.log(`✅ Deleted student: ${studentPin} from ${batchId}`);
}

// ==========================================
// ROLE MANAGEMENT (RBAC)
// ==========================================

/**
 * Hardcoded admin usernames (bootstrap list).
 * These usernames are ALWAYS treated as admins regardless of the /roles node.
 * Add your admin usernames here (lowercase, without @gmail.com).
 */
const ADMIN_USERNAMES = ['admin', 'prasad', 'techwing'];

/**
 * Fetch user role from Firebase RTDB (/roles/{uid})
 * Returns 'admin' or 'user'
 */
async function fetchUserRole(uid) {
    try {
        const snapshot = await database.ref(`/roles/${uid}`).once('value');
        const role = snapshot.val();
        return role === 'admin' ? 'admin' : 'user';
    } catch (error) {
        console.error('❌ Error fetching user role:', error);
        return 'user'; // Default to user on error
    }
}

/**
 * Set user role in Firebase RTDB (/roles/{uid})
 * Should only be called by admins
 */
async function setUserRole(uid, role) {
    try {
        await database.ref(`/roles/${uid}`).set(role);
        console.log(`✅ Set role for ${uid}: ${role}`);
    } catch (error) {
        console.error('❌ Error setting user role:', error);
        throw error;
    }
}

/**
 * Check if a username is in the hardcoded admin list
 */
function isHardcodedAdmin(username) {
    return ADMIN_USERNAMES.includes(username.toLowerCase().trim());
}

/**
 * Save Mock Interview Feedback
 */
async function saveMockInterview(batchId, studentPin, interviewData) {
    const timestamp = Date.now();
    const ref = database.ref(`/interviews/${batchId}/${studentPin}/${timestamp}`);
    await ref.set(interviewData);
    console.log(`✅ Saved interview for ${studentPin}`);
}

/**
 * Fetch mock interviews for a student
 */
async function fetchStudentMockInterviews(batchId, studentPin) {
    const snapshot = await database.ref(`/interviews/${batchId}/${studentPin}`).once('value');
    return snapshot.val() || {};
}

// Export for use in app.js
window.FirebaseService = {
    signInWithUsername,
    signOut,
    getCurrentUser,
    fetchBatches,
    fetchStudents,
    fetchAttendance,
    fetchBatchAttendanceHistory,
    markAttendance,
    saveMockInterview,
    fetchStudentMockInterviews, // Exported
    addBatch,
    deleteBatch,
    addStudent,
    deleteStudent,
    fetchUserRole,
    setUserRole,
    isHardcodedAdmin,
    ADMIN_USERNAMES,
    getTodayDateFormatted,
    listenToAttendance,
    auth,
    database
};
