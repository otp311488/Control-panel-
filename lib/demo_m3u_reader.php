<?php
// Clean up URLs by removing surrounding quotes (from cleanUrl)
function cleanDemoUrl($url) {
    $url = trim($url);
    if (preg_match('/^"(.*)"$/', $url, $matches)) {
        $url = $matches[1];
    }
    return $url;
}

// Parse M3U content (from parseM3UContent)
function parseDemoM3UContent($content) {
    $lines = explode("\n", $content);
    $channels = [];
    $channel = null;

    foreach ($lines as $line) {
        $line = trim($line);
        if (empty($line)) {
            continue; // Skip empty lines
        }

        error_log("Parsing line: $line");

        // Skip lines that start with "stream"
        if (strpos($line, 'stream ') === 0) {
            continue;
        }

        if (strpos($line, '#EXTINF:') === 0) {
            if ($channel !== null) {
                $channels[] = $channel;
            }
            $channel = [
                "channelId" => "",
                "channelName" => "*",
                "channelPlayUrl" => "",
                "audioInfo" => [],
                "channelCategory" => "**",
                "channelLanguage" => "*",
                "categoryId" => "**",
                "languageId" => 0,
                "multiCastUrl" => null,
                "unicastDashUrl" => null,
                "unicastHlsUrl" => null,
                "multiAudio" => false
            ];
            // Parse attributes in #EXTINF line
            preg_match_all('/(\w+)\s*=\s*("([^"]*)"|[^,]+)(?:,|$)/', $line, $matches, PREG_SET_ORDER);
            foreach ($matches as $match) {
                $key = trim($match[1]);
                $value = isset($match[3]) ? trim($match[3]) : trim($match[2]);
                // Remove quotes from the value if present
                $value = trim($value, '"');
                // For unquoted values, take only the part before the next comma or space
                if (strpos($value, ',') !== false) {
                    $value = trim(explode(',', $value)[0]);
                }
                // Skip channelLogoUrl and channelmainLogoUrl (case-insensitive)
                if (strtolower($key) === 'channellogourl' || strtolower($key) === 'channelmainlogourl') {
                    continue;
                }
                // Map attributes to the appropriate fields
                switch ($key) {
                    case 'channelName':
                        $channel["channelName"] = $value;
                        break;
                    case 'channelCategory':
                        $channel["channelCategory"] = $value;
                        break;
                    case 'channelLanguage':
                        $channel["channelLanguage"] = $value;
                        break;
                    case 'categoryId':
                        $channel["categoryId"] = $value;
                        break;
                    case 'languageId':
                        $channel["languageId"] = (int)$value;
                        break;
                    case 'multiCastUrl':
                        $channel["multiCastUrl"] = ($value === 'null') ? null : $value;
                        break;
                    case 'unicastDashUrl':
                        $channel["unicastDashUrl"] = ($value === 'null') ? null : $value;
                        break;
                    case 'unicastHlsUrl':
                        $channel["unicastHlsUrl"] = ($value === 'null') ? null : $value;
                        break;
                    case 'multiAudio':
                        $channel["multiAudio"] = ($value === 'true');
                        break;
                }
                error_log("Parsed attribute: $key = $value");
            }
            error_log("Parsed channel: " . ($channel['channelName'] ?? 'Unknown'));
        } elseif (!empty($line) && $channel !== null) {
            // Handle the channelPlayUrl line
            $url = trim($line);
            $url = preg_replace('/^channelPlayUrl\s*=\s*/i', '', $url);
            $url = cleanDemoUrl($url);
            if (filter_var($url, FILTER_VALIDATE_URL)) {
                $channel["channelPlayUrl"] = $url;
                error_log("Set URL for " . ($channel['channelName'] ?? 'Unknown') . ": $url");
                $channels[] = $channel;
                $channel = null;
            } else {
                error_log("Invalid URL skipped for " . ($channel['channelName'] ?? 'Unknown') . ": $url");
            }
        }
    }
    if ($channel !== null) {
        error_log("Adding leftover channel: " . ($channel['channelName'] ?? 'Unknown'));
        $channels[] = $channel;
    }
    error_log("Total channels parsed: " . count($channels));
    return $channels;
}

// Assign sequential channel IDs (from assignChannelIds)
function assignDemoChannelIds($channels) {
    $counter = 1;
    foreach ($channels as &$channel) {
        $channel['channelId'] = (string)$counter;
        $counter++;
    }
    unset($channel);
    return $channels;
}



?>