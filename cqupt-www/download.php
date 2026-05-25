<?php
/**
 * CQUPT Schedule App - Android APK Smart Redirect Downloader
 * Scans the 'download' directory, finds the first .apk file, and redirects to it.
 * Fallback: Redirects to GitHub Releases if no APK is found.
 */

// Define paths
$downloadDir = __DIR__ . '/download';
$fallbackUrl = 'https://github.com/MeTerminator/cqupt-schedule-app/releases';

// Check if download directory exists
if (is_dir($downloadDir)) {
    // Scan directory for .apk files
    $files = scandir($downloadDir);
    $apkFiles = [];

    foreach ($files as $file) {
        // Exclude parent directories and check for .apk extension
        if ($file !== '.' && $file !== '..' && strtolower(pathinfo($file, PATHINFO_EXTENSION)) === 'apk') {
            $apkFiles[] = $file;
        }
    }

    // Sort files naturally (latest or alphabetical first)
    natsort($apkFiles);
    $apkFiles = array_values($apkFiles);

    // If we found an APK, redirect to it!
    if (!empty($apkFiles)) {
        $apkFile = $apkFiles[0];
        
        // Redirect to the local APK file path
        header('Location: /download/' . rawurlencode($apkFile));
        exit;
    }
}

// Fallback to GitHub Releases if no local APK is present
header('Location: ' . $fallbackUrl);
exit;
