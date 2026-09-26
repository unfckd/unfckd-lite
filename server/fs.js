/*
    unfckd-lite - Free resource scanner for FiveM & RedM
    Copyright (C) 2026 Damian Paape (LuvvSumDev)
    Licensed under GPL-3.0 with additional terms, see LICENSE and NOTICE
    https://github.com/unfckd/unfckd-lite
*/

'use strict';

const fs = require('fs');
const path = require('path');

const RESOURCE_NAME = GetCurrentResourceName();
const REPORTS_DIR = path.join(GetResourcePath(RESOURCE_NAME), 'reports');
const REPORT_NAME = /^unfckd-report-[\w-]+\.(txt|json)$/;
const MAX_FILE_SIZE = 2 * 1024 * 1024; // 2 MB

const toForwardSlashes = (value) => value.replace(/\\/g, '/');

function logError(message) {
    console.log(`^5[unfckd-lite]^7 ^1${message}^7`);
}

function isInternalCall() {
    const invoker = GetInvokingResource();

    return !invoker || invoker === RESOURCE_NAME;
}

function pruneReports(keep) {
    const reports = fs
        .readdirSync(REPORTS_DIR)
        .filter((name) => REPORT_NAME.test(name))
        .sort()
        .reverse();

    for (const name of reports.slice(keep)) {
        try {
            fs.unlinkSync(path.join(REPORTS_DIR, name));
        } catch (error) {
            logError(`Could not delete old report ${name}: ${error.message}`);
        }
    }
}

exports('readFile', (filePath) => {
    if (!isInternalCall() || typeof filePath !== 'string') {
        return null;
    }

    try {
        const stats = fs.statSync(filePath);

        if (!stats.isFile() || stats.size > MAX_FILE_SIZE) {
            return null;
        }

        return fs.readFileSync(filePath, 'utf8').replace(/^\uFEFF/, '');
    } catch {
        return null;
    }
});

exports('findMissingFiles', (basePath, relativePaths) => {
    if (!isInternalCall() || typeof basePath !== 'string' || !Array.isArray(relativePaths)) {
        return [];
    }

    return relativePaths.filter((relativePath) => typeof relativePath === 'string' && !fs.existsSync(path.join(basePath, relativePath)));
});

exports('writeReport', (fileName, content, keep) => {
    if (!isInternalCall()) {
        return null;
    }

    const safeName = path.basename(String(fileName));

    if (!REPORT_NAME.test(safeName) || typeof content !== 'string') {
        logError(`Refused to write report "${safeName}" due to invalid name or content`);
        return null;
    }

    try {
        const target = path.join(REPORTS_DIR, safeName);

        fs.mkdirSync(REPORTS_DIR, { recursive: true });
        fs.writeFileSync(target, content, 'utf8');
        pruneReports(Math.max(1, Math.floor(Number(keep)) || 1));

        return toForwardSlashes(target);
    } catch (error) {
        logError(`Could not write report "${safeName}": ${error.message}`);
        return null;
    }
});
