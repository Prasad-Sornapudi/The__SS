/* ==========================================
   TechWing Attendance - Mock Data
   ========================================== */

// Login Credentials
const mockCredentials = [
    { username: 'admin', password: 'admin123', name: 'Admin User', role: 'Admin' },
    { username: 'faculty', password: 'faculty123', name: 'Dr. Rajesh Kumar', role: 'Faculty' },
    { username: 'demo', password: 'demo', name: 'Demo User', role: 'Faculty' }
];

// Batches
const mockBatches = [
    {
        id: 'batch-2024',
        name: '2024 Batch',
        year: 2024,
        totalStudents: 180,
        combos: ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'],
        progress: 75
    },
    {
        id: 'batch-2023',
        name: '2023 Batch',
        year: 2023,
        totalStudents: 165,
        combos: ['A1', 'A2', 'B1', 'B2', 'C1'],
        progress: 92
    },
    {
        id: 'batch-2025',
        name: '2025 Batch',
        year: 2025,
        totalStudents: 200,
        combos: ['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'D1'],
        progress: 45
    }
];

// Helper function to generate students
function generateStudents(batchId, count) {
    const branches = ['CSE', 'ECE', 'EEE', 'MECH', 'CIVIL', 'IT'];
    const combos = mockBatches.find(b => b.id === batchId)?.combos || ['A1'];
    const firstNames = ['Arun', 'Priya', 'Ravi', 'Sneha', 'Karthik', 'Divya', 'Vikram', 'Ananya', 'Rahul', 'Meera',
        'Arjun', 'Kavya', 'Suresh', 'Lakshmi', 'Manoj', 'Pooja', 'Venkat', 'Swathi', 'Kumar', 'Deepa',
        'Sanjay', 'Nithya', 'Prasad', 'Revathi', 'Ganesh', 'Bhavani', 'Harish', 'Sangeetha', 'Mohan', 'Vidya'];
    const lastNames = ['Kumar', 'Reddy', 'Sharma', 'Naidu', 'Rao', 'Patel', 'Singh', 'Gupta', 'Iyer', 'Nair',
        'Verma', 'Joshi', 'Menon', 'Pillai', 'Choudhary', 'Banerjee', 'Das', 'Ghosh', 'Sen', 'Mukherjee'];

    const students = [];
    const yearPrefix = batchId.split('-')[1]?.substring(2) || '24';

    for (let i = 1; i <= count; i++) {
        const firstName = firstNames[Math.floor(Math.random() * firstNames.length)];
        const lastName = lastNames[Math.floor(Math.random() * lastNames.length)];
        const branch = branches[Math.floor(Math.random() * branches.length)];
        const combo = combos[Math.floor(Math.random() * combos.length)];
        const pinNumber = `${yearPrefix}${branch.substring(0, 2)}${String(i).padStart(3, '0')}`;

        students.push({
            id: `student-${batchId}-${i}`,
            pinNumber: pinNumber,
            name: `${firstName} ${lastName}`,
            email: `${firstName.toLowerCase()}.${lastName.toLowerCase()}@techwing.edu`,
            phone: `9${Math.floor(Math.random() * 900000000 + 100000000)}`,
            mobileNumber: `9${Math.floor(Math.random() * 900000000 + 100000000)}`,
            branch: branch,
            combo: combo,
            securityCodes: [`SC${Math.floor(Math.random() * 9000 + 1000)}`, `SC${Math.floor(Math.random() * 9000 + 1000)}`]
        });
    }

    return students;
}

// Batches with students
const mockClasses = [
    {
        id: 'class-cse-a',
        className: 'CSE Section A',
        classCode: 'CSE-A-2024',
        sheetId: 'sheet-001',
        batchId: 'batch-2024',
        attendanceSheetName: 'Attendance_CSE_A',
        students: generateStudents('batch-2024', 60),
        lastSyncTime: '2024-02-06 09:30:00',
        lastAttendanceSyncTime: '2024-02-06 14:00:00',
        createdAt: new Date('2024-01-15'),
        updatedAt: new Date('2024-02-06')
    },
    {
        id: 'class-cse-b',
        className: 'CSE Section B',
        classCode: 'CSE-B-2024',
        sheetId: 'sheet-002',
        batchId: 'batch-2024',
        attendanceSheetName: 'Attendance_CSE_B',
        students: generateStudents('batch-2024', 58),
        lastSyncTime: '2024-02-06 09:15:00',
        lastAttendanceSyncTime: '2024-02-06 13:45:00',
        createdAt: new Date('2024-01-15'),
        updatedAt: new Date('2024-02-06')
    },
    {
        id: 'class-ece-a',
        className: 'ECE Section A',
        classCode: 'ECE-A-2024',
        sheetId: 'sheet-003',
        batchId: 'batch-2024',
        attendanceSheetName: 'Attendance_ECE_A',
        students: generateStudents('batch-2024', 55),
        lastSyncTime: '2024-02-05 16:00:00',
        lastAttendanceSyncTime: '2024-02-05 17:30:00',
        createdAt: new Date('2024-01-16'),
        updatedAt: new Date('2024-02-05')
    },
    {
        id: 'class-2023-cse',
        className: 'CSE 2023 Batch',
        classCode: 'CSE-2023',
        sheetId: 'sheet-004',
        batchId: 'batch-2023',
        attendanceSheetName: 'Attendance_CSE_2023',
        students: generateStudents('batch-2023', 65),
        lastSyncTime: '2024-02-04 11:00:00',
        lastAttendanceSyncTime: '2024-02-04 16:00:00',
        createdAt: new Date('2023-06-10'),
        updatedAt: new Date('2024-02-04')
    },
    {
        id: 'class-2025-mixed',
        className: 'Mixed Section 2025',
        classCode: 'MIX-2025',
        sheetId: 'sheet-005',
        batchId: 'batch-2025',
        attendanceSheetName: 'Attendance_2025',
        students: generateStudents('batch-2025', 70),
        lastSyncTime: '2024-02-06 10:00:00',
        lastAttendanceSyncTime: '2024-02-06 12:00:00',
        createdAt: new Date('2024-01-20'),
        updatedAt: new Date('2024-02-06')
    }
];

// Generate attendance records for today
function generateTodayAttendance(classId) {
    const classData = mockClasses.find(c => c.id === classId);
    if (!classData) return [];

    const today = new Date();
    const attendance = [];

    classData.students.forEach((student, index) => {
        // Randomly mark ~75% as present
        const isPresent = Math.random() > 0.25;

        if (isPresent) {
            const hour = 8 + Math.floor(Math.random() * 4);
            const minute = Math.floor(Math.random() * 60);

            attendance.push({
                id: `att-${classId}-${student.pinNumber}-${today.toISOString().split('T')[0]}`,
                studentId: student.id,
                pinNumber: student.pinNumber,
                studentName: student.name,
                classId: classId,
                date: today.toISOString().split('T')[0],
                timestamp: new Date(today.getFullYear(), today.getMonth(), today.getDate(), hour, minute).toISOString(),
                status: 'present',
                scanMethod: Math.random() > 0.7 ? 'manual' : 'qr',
                sessionType: hour < 12 ? 'morning' : 'afternoon',
                synced: Math.random() > 0.3
            });
        }
    });

    return attendance;
}

// Mock Interview History
const mockInterviews = [
    {
        id: 'int-001',
        studentId: 'student-batch-2024-1',
        studentName: 'Arun Kumar',
        studentPin: '24CS001',
        classId: 'class-cse-a',
        interviewDate: '2024-02-01',
        aptitude: {
            quantitative: 'Good',
            logical: 'Excellent',
            verbal: 'Average'
        },
        technical: {
            programming: 'Good',
            dsa: 'Average',
            problemSolving: 'Good'
        },
        hr: {
            communication: 'Good',
            confidence: 'Excellent',
            bodyLanguage: 'Good'
        },
        profile: {
            linkedinScore: 75,
            githubScore: 60,
            leetcodeCount: 120
        },
        overallRating: 4,
        notes: 'Good technical understanding. Needs to improve verbal communication.',
        createdAt: new Date('2024-02-01T14:30:00')
    },
    {
        id: 'int-002',
        studentId: 'student-batch-2024-5',
        studentName: 'Karthik Reddy',
        studentPin: '24CS005',
        classId: 'class-cse-a',
        interviewDate: '2024-02-03',
        aptitude: {
            quantitative: 'Excellent',
            logical: 'Good',
            verbal: 'Good'
        },
        technical: {
            programming: 'Excellent',
            dsa: 'Good',
            problemSolving: 'Excellent'
        },
        hr: {
            communication: 'Excellent',
            confidence: 'Good',
            bodyLanguage: 'Excellent'
        },
        profile: {
            linkedinScore: 90,
            githubScore: 85,
            leetcodeCount: 250
        },
        overallRating: 5,
        notes: 'Exceptional candidate. Strong in all areas.',
        createdAt: new Date('2024-02-03T11:00:00')
    },
    {
        id: 'int-003',
        studentId: 'student-batch-2024-3',
        studentName: 'Sneha Sharma',
        studentPin: '24EC003',
        classId: 'class-ece-a',
        interviewDate: '2024-02-05',
        aptitude: {
            quantitative: 'Average',
            logical: 'Good',
            verbal: 'Excellent'
        },
        technical: {
            programming: 'Average',
            dsa: 'Poor',
            problemSolving: 'Average'
        },
        hr: {
            communication: 'Excellent',
            confidence: 'Good',
            bodyLanguage: 'Good'
        },
        profile: {
            linkedinScore: 65,
            githubScore: 40,
            leetcodeCount: 45
        },
        overallRating: 3,
        notes: 'Good communication skills but needs to work on DSA.',
        createdAt: new Date('2024-02-05T15:00:00')
    }
];

// App State
const appState = {
    isLoggedIn: false,
    currentUser: null,
    currentScreen: 'login',
    activeClass: null,
    sessionType: 'morning',
    sessionDate: new Date().toISOString().split('T')[0],
    attendanceRecords: [],
    recentScans: [],
    syncPending: 0,
    selectedBatch: null,
    searchResults: [],
    interviewFormData: {
        classId: null,
        studentId: null,
        date: new Date().toISOString().split('T')[0],
        aptitude: {},
        technical: {},
        hr: {},
        profile: { linkedinScore: 0, githubScore: 0, leetcodeCount: 0 },
        overallRating: 0,
        notes: ''
    }
};

// Helper function to get student by PIN
function getStudentByPin(pin) {
    for (const classData of mockClasses) {
        const student = classData.students.find(s => s.pinNumber === pin);
        if (student) {
            return { student, classData };
        }
    }
    return null;
}

// Helper function to search students
function searchStudents(query, filters = {}) {
    const results = [];
    const queryLower = query.toLowerCase();

    for (const classData of mockClasses) {
        for (const student of classData.students) {
            let matches = false;

            if (student.name.toLowerCase().includes(queryLower) ||
                student.pinNumber.toLowerCase().includes(queryLower) ||
                student.email.toLowerCase().includes(queryLower)) {
                matches = true;
            }

            // Apply filters
            if (matches && filters.classId && classData.id !== filters.classId) {
                matches = false;
            }
            if (matches && filters.branch && student.branch !== filters.branch) {
                matches = false;
            }
            if (matches && filters.combo && student.combo !== filters.combo) {
                matches = false;
            }

            if (matches) {
                results.push({
                    ...student,
                    className: classData.className,
                    classId: classData.id
                });
            }
        }
    }

    return results;
}

// Helper function to get unique branches/combos
function getUniqueBranches() {
    const branches = new Set();
    mockClasses.forEach(c => c.students.forEach(s => branches.add(s.branch)));
    return Array.from(branches).sort();
}

function getUniqueCombos() {
    const combos = new Set();
    mockClasses.forEach(c => c.students.forEach(s => combos.add(s.combo)));
    return Array.from(combos).sort();
}

// Helper function to format date
function formatDate(date) {
    const d = new Date(date);
    return d.toLocaleDateString('en-IN', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric'
    });
}

function formatTime(date) {
    const d = new Date(date);
    return d.toLocaleTimeString('en-IN', {
        hour: '2-digit',
        minute: '2-digit'
    });
}

function formatDateTime(date) {
    return `${formatDate(date)} ${formatTime(date)}`;
}

// Export for app.js
window.mockData = {
    credentials: mockCredentials,
    batches: mockBatches,
    classes: mockClasses,
    interviews: mockInterviews,
    appState: appState,
    generateTodayAttendance,
    getStudentByPin,
    searchStudents,
    getUniqueBranches,
    getUniqueCombos,
    formatDate,
    formatTime,
    formatDateTime
};
