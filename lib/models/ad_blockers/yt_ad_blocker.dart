// Add these constants to your class
class YouTubeAdBlocker {
  // Network filter patterns (block requests)
  static final List<String> blockedUrlPatterns = [
    // YouTube ad serving
    'youtube.com/api/stats/ads',
    'youtube.com/api/stats/atr',
    'youtube.com/ptracking',
    'youtube.com/pagead/',
    'youtube.com/get_midroll_',
    'youtube.com/ad_data_204',
    'youtube.com/annotations_invideo',
    
    // Ad parameters in video URLs
    'googlevideo.com/videoplayback?',
  ];

  static final List<String> blockedUrlParams = [
    'ad_cpn=',
    'ad_type=',
    'adformat=',
    'ad_flags=',
    'adunit=',
    'ad_tag=',
  ];

  // Cosmetic filters (CSS selectors to hide)
  static final List<String> hiddenSelectors = [
    // Video player ads
    '.video-ads',
    '.ytp-ad-module',
    '.ytp-ad-overlay-container',
    '.ytp-ad-overlay-image',
    '.ytp-ad-text-overlay',
    '.ytp-ad-player-overlay',
    '.ytp-ad-player-overlay-instream-info',
    '.ytp-ad-image-overlay',
    '.ytp-ad-overlay-close-button',
    
    // Promoted content
    'ytd-promoted-sparkles-web-renderer',
    'ytd-promoted-video-renderer',
    'ytd-compact-promoted-video-renderer',
    'ytd-promoted-sparkles-text-search-renderer',
    
    // Display ads
    'ytd-display-ad-renderer',
    'ytd-ad-slot-renderer',
    'ytd-banner-promo-renderer',
    'ytd-video-masthead-ad-v3-renderer',
    'ytd-statement-banner-renderer',
    'ytd-in-feed-ad-layout-renderer',
    'ytd-brand-video-singleton-renderer',
    'ytd-player-legacy-desktop-watch-ads-renderer',
    
    // Sidebar/masthead ads
    '#masthead-ad',
    '#player-ads',
    '.ytd-merch-shelf-renderer',
    'ytd-action-companion-ad-renderer',
    
    // Mobile ads
    '.mobile-topbar-ad',
    'ytm-promoted-sparkles-web-renderer',
  ];

  static bool shouldBlockUrl(String url) {
    final lowerUrl = url.toLowerCase();
    
    // Check URL patterns
    for (var pattern in blockedUrlPatterns) {
      if (lowerUrl.contains(pattern)) {
        return true;
      }
    }
    
    // Check URL parameters
    for (var param in blockedUrlParams) {
      if (lowerUrl.contains(param)) {
        return true;
      }
    }
    
    return false;
  }

  static String getCosmeticFilterScript() {
    final selectorsJson = hiddenSelectors.map((s) => "'$s'").join(',');
    
    return """
      (function() {
        var hiddenSelectors = [$selectorsJson];
        
        function removeAds() {
          // Hide ad elements using CSS selectors
          hiddenSelectors.forEach(function(selector) {
            try {
              document.querySelectorAll(selector).forEach(function(el) {
                el.style.display = 'none';
                el.remove();
              });
            } catch(e) {}
          });
          
          // Auto-click skip button
          var skipButtons = [
            '.ytp-ad-skip-button',
            '.ytp-ad-skip-button-modern',
            '.ytp-skip-ad-button',
            'button.ytp-ad-skip-button'
          ];
          
          skipButtons.forEach(function(selector) {
            try {
              var btn = document.querySelector(selector);
              if (btn) btn.click();
            } catch(e) {}
          });
          
          // Speed through short non-skippable ads
          try {
            var video = document.querySelector('video');
            if (video && video.duration) {
              var isAd = document.querySelector('.ytp-ad-player-overlay, .video-ads');
              
              if (isAd && video.duration < 30 && video.duration > 0) {
                // Fast forward to near end
                video.playbackRate = 16;
                video.muted = true;
                if (video.currentTime < video.duration - 0.5) {
                  video.currentTime = video.duration - 0.5;
                }
              } else if (!isAd) {
                // Reset playback for normal videos
                video.playbackRate = 1;
                video.muted = false;
              }
            }
          } catch(e) {}
        }
        
        // Run immediately
        removeAds();
        
        // Run every 500ms for dynamic content
        setInterval(removeAds, 500);
        
        // Watch for DOM changes
        try {
          var observer = new MutationObserver(function() {
            removeAds();
          });
          
          observer.observe(document.body, {
            childList: true,
            subtree: true
          });
        } catch(e) {}
      })();
    """;
  }
}