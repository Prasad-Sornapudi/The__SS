/**
 * TechWing LMS - Google Apps Script
 * Syncs Sync Sheet data to Firebase Realtime Database
 * 
 * SETUP:
 * 1. Open your Sync Sheet in Google Sheets
 * 2. Go to Extensions > Apps Script
 * 3. Paste this entire code
 * 4. Update FIREBASE_URL and FIREBASE_SECRET below
 * 5. Run initialSync() once
 * 6. Set up onChange trigger for autoSync
 */

// ==========================================
// CONFIGURATION - UPDATE THESE VALUES
// ==========================================
const FIREBASE_URL = 'https://tw-attendance-default-rtdb.firebaseio.com';
const FIREBASE_SECRET = '5Z70xFdfIggQbpZRgUkyCzCOSml35BYQJwxF7Pf8'; // Get from Firebase Console > Project Settings > Service Accounts > Database Secrets

// Column mapping (1-indexed)
const COLUMNS = {
  NAME: 1,      // A - Name of the Student
  PIN: 2,       // B - Pin-number
  BRANCH: 3,    // C - Branch
  EMAIL: 4,     // D - Mail-id
  PHONE: 5,     // E - Mobile Number
  COMBO: 6,     // F - COMBO
  SEC_CODE: 7   // G - Sec-Codes
};

// ==========================================
// MAIN SYNC FUNCTIONS
// ==========================================

/**
 * Initial full sync - Run this once to populate Firebase
 */
function initialSync() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheets = ss.getSheets();
  
  Logger.log('Starting initial sync...');
  
  // Clear existing data
  firebaseDelete('/students');
  firebaseDelete('/batches');
  
  sheets.forEach(sheet => {
    const sheetName = sheet.getName();
    
    // Skip sheets that aren't batch tabs
    if (sheetName.toLowerCase().includes('template') || 
        sheetName.toLowerCase().includes('master')) {
      Logger.log(`Skipping sheet: ${sheetName}`);
      return;
    }
    
    syncBatchSheet(sheet);
  });
  
  Logger.log('Initial sync complete!');
}

/**
 * Sync a single batch sheet to Firebase
 */
function syncBatchSheet(sheet) {
  const sheetName = sheet.getName();
  const batchId = sheetNameToBatchId(sheetName);
  
  Logger.log(`Syncing batch: ${sheetName} -> ${batchId}`);
  
  // Create batch entry
  const batchData = {
    name: sheetName,
    sheetTabName: sheetName,
    lastSync: new Date().toISOString()
  };
  firebasePut(`/batches/${batchId}`, batchData);
  
  // Get all data from sheet
  const data = sheet.getDataRange().getValues();
  if (data.length < 2) {
    Logger.log(`No data in sheet: ${sheetName}`);
    return;
  }
  
  const headers = data[0];
  const students = {};
  
  // Find attendance date columns (columns after G)
  const attendanceDates = [];
  for (let i = COLUMNS.SEC_CODE; i < headers.length; i++) {
    const header = headers[i];
    if (header && isDateColumn(header)) {
      attendanceDates.push({ index: i, date: formatDateHeader(header) });
    }
  }
  
  // Process each student row
  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    const pin = String(row[COLUMNS.PIN - 1]).trim();
    
    if (!pin) continue; // Skip empty rows
    
    // Student data
    students[pin] = {
      name: String(row[COLUMNS.NAME - 1]).trim(),
      pin: pin,
      branch: String(row[COLUMNS.BRANCH - 1]).trim(),
      email: String(row[COLUMNS.EMAIL - 1]).trim(),
      phone: String(row[COLUMNS.PHONE - 1]).trim(),
      combo: String(row[COLUMNS.COMBO - 1]).trim(),
      secCode: String(row[COLUMNS.SEC_CODE - 1]).trim()
    };
    
    // Process attendance for this student
    attendanceDates.forEach(dateCol => {
      const cellValue = String(row[dateCol.index]).trim();
      if (cellValue && cellValue.toUpperCase() !== '') {
        syncAttendanceFromCell(batchId, dateCol.date, pin, cellValue);
      }
    });
  }
  
  // Write students to Firebase
  firebasePut(`/students/${batchId}`, students);
  Logger.log(`Synced ${Object.keys(students).length} students from ${sheetName}`);
}

/**
 * Auto-sync trigger - Call this on sheet change
 */
function autoSync(e) {
  const sheet = e.source.getActiveSheet();
  const range = e.range;
  
  // Re-sync the entire batch (simpler and more reliable)
  syncBatchSheet(sheet);
}

/**
 * Set up the onChange trigger
 * Run this once to enable auto-sync
 */
function setupTrigger() {
  // Remove existing triggers
  const triggers = ScriptApp.getProjectTriggers();
  triggers.forEach(trigger => {
    if (trigger.getHandlerFunction() === 'autoSync') {
      ScriptApp.deleteTrigger(trigger);
    }
  });
  
  // Create new onChange trigger
  ScriptApp.newTrigger('autoSync')
    .forSpreadsheet(SpreadsheetApp.getActiveSpreadsheet())
    .onChange()
    .create();
  
  Logger.log('Trigger set up successfully!');
}

// ==========================================
// ATTENDANCE HELPERS
// ==========================================

function syncAttendanceFromCell(batchId, date, pin, cellValue) {
  // Cell might contain "P" or "P,P" for multiple sessions
  const sessions = cellValue.split(',').map(s => s.trim()).filter(s => s);
  
  sessions.forEach((session, index) => {
    if (session.toUpperCase() === 'P') {
      const scanData = {
        time: index === 0 ? '09:00' : '14:00',
        session: index === 0 ? 'morning' : 'afternoon',
        method: 'sheet',
        syncedAt: new Date().toISOString()
      };
      
      // Push to scans array
      firebasePost(`/attendance/${batchId}/${date}/${pin}/scans`, scanData);
    }
  });
}

// ==========================================
// FIREBASE HELPER FUNCTIONS
// ==========================================

function firebasePut(path, data) {
  const url = `${FIREBASE_URL}${path}.json?auth=${FIREBASE_SECRET}`;
  const options = {
    method: 'put',
    contentType: 'application/json',
    payload: JSON.stringify(data),
    muteHttpExceptions: true
  };
  
  const response = UrlFetchApp.fetch(url, options);
  if (response.getResponseCode() !== 200) {
    Logger.log(`Firebase PUT error: ${response.getContentText()}`);
  }
  return response;
}

function firebasePost(path, data) {
  const url = `${FIREBASE_URL}${path}.json?auth=${FIREBASE_SECRET}`;
  const options = {
    method: 'post',
    contentType: 'application/json',
    payload: JSON.stringify(data),
    muteHttpExceptions: true
  };
  
  const response = UrlFetchApp.fetch(url, options);
  if (response.getResponseCode() !== 200) {
    Logger.log(`Firebase POST error: ${response.getContentText()}`);
  }
  return response;
}

function firebaseDelete(path) {
  const url = `${FIREBASE_URL}${path}.json?auth=${FIREBASE_SECRET}`;
  const options = {
    method: 'delete',
    muteHttpExceptions: true
  };
  
  const response = UrlFetchApp.fetch(url, options);
  return response;
}

// ==========================================
// UTILITY FUNCTIONS
// ==========================================

function sheetNameToBatchId(name) {
  // Convert "Batch 2024" -> "batch_2024"
  return name.toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '');
}

function isDateColumn(header) {
  // Check if header looks like a date (DD-MM-YY format)
  if (!header) return false;
  const str = String(header);
  return /^\d{2}-\d{2}-\d{2}$/.test(str) || header instanceof Date;
}

function formatDateHeader(header) {
  if (header instanceof Date) {
    const dd = String(header.getDate()).padStart(2, '0');
    const mm = String(header.getMonth() + 1).padStart(2, '0');
    const yy = String(header.getFullYear()).slice(-2);
    return `${dd}-${mm}-${yy}`;
  }
  return String(header);
}

function getTodayDate() {
  const now = new Date();
  const dd = String(now.getDate()).padStart(2, '0');
  const mm = String(now.getMonth() + 1).padStart(2, '0');
  const yy = String(now.getFullYear()).slice(-2);
  return `${dd}-${mm}-${yy}`;
}

// ==========================================
// MENU
// ==========================================

function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('TechWing Sync')
    .addItem('Initial Sync to Firebase', 'initialSync')
    .addItem('Setup Auto-Sync Trigger', 'setupTrigger')
    .addItem('Sync Current Sheet', 'syncCurrentSheet')
    .addToUi();
}

function syncCurrentSheet() {
  const sheet = SpreadsheetApp.getActiveSheet();
  syncBatchSheet(sheet);
  SpreadsheetApp.getUi().alert('Sync complete!');
}
