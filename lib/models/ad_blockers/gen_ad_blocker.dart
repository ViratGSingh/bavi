// Add this class for general ad blocking
class GeneralAdBlocker {
  // Major ad networks and trackers
  static final List<String> blockedDomains = [
    // Google ads
    'doubleclick.net',
    'googlesyndication.com',
    'adservice.google.com',
    'googleadservices.com',
    'google-analytics.com',
    'googletagmanager.com',
    'googletagservices.com',
    
    // Other major ad networks
    'ads.yahoo.com',
    'advertising.com',
    'media.net',
    'adnxs.com',
    'adsrvr.org',
    'criteo.com',
    'outbrain.com',
    'taboola.com',
    'pubmatic.com',
    'rubiconproject.com',
    'openx.net',
    'contextweb.com',
    'advertising.microsoft.com',
    'smartadserver.com',
    'adform.net',
    'amazon-adsystem.com',
    'casalemedia.com',
    'lijit.com',
    'sovrn.com',
    'yieldmo.com',
    '33across.com',
    'indexww.com',
    'serving-sys.com',
    'adsafeprotected.com',
    'moatads.com',
    'scorecardresearch.com',
    'imrworldwide.com',
    'quantserve.com',
  ];

  static final List<String> blockedUrlPatterns = [
    '/ads/',
    '/adv/',
    '/banner',
    '/sponsored',
    '/pagead/',
    'ad.php',
    'ads.js',
    'adserver',
    'adtech',
    'advertising',
    'advert',
    '/ad-',
    '-ad.',
    '/ad_',
    '_ad.',
    'ad_units',
    'adsbygoogle',
  ];

  static bool shouldBlockRequest(String url, String host) {
    final lowerUrl = url.toLowerCase();
    final lowerHost = host.toLowerCase();
    
    // Check if domain is in blocked list
    for (var domain in blockedDomains) {
      if (lowerHost.contains(domain)) {
        return true;
      }
    }
    
    // Check URL patterns
    for (var pattern in blockedUrlPatterns) {
      if (lowerUrl.contains(pattern)) {
        return true;
      }
    }
    
    return false;
  }

  static String getAdRemovalScript() {
    return """
      (function() {
        function removeGeneralAds() {
          // Remove Google AdSense
          document.querySelectorAll('ins.adsbygoogle, iframe[src*="googlesyndication"]').forEach(function(el) {
            el.remove();
          });
          
          // Remove common ad containers
          var adSelectors = [
            '[id*="google_ads"]',
            '[class*="google-ad"]',
            '[id*="div-gpt-ad"]',
            '[class*="adsbygoogle"]',
            '[data-ad-slot]',
            '[data-google-query-id]',
            'div[id^="ad_"]',
            'div[id*="_ad_"]',
            'div[class*="ad-container"]',
            'div[class*="advertisement"]',
            'div[class*="sponsored"]',
            'aside[class*="ad"]',
            '.banner-ad',
            '.ad-banner',
            '.ad-wrapper',
            '.ad-slot',
            '.advert',
            '[id*="AdSpace"]',
            '[class*="AdSpace"]',
          ];
          
          adSelectors.forEach(function(selector) {
            try {
              document.querySelectorAll(selector).forEach(function(el) {
                // Check if it's actually an ad (not just contains 'ad' in class name)
                var text = el.textContent.toLowerCase();
                var hasAdIndicator = el.querySelector('ins.adsbygoogle') || 
                                    el.querySelector('iframe[src*="doubleclick"]') ||
                                    el.querySelector('iframe[src*="googlesyndication"]') ||
                                    el.hasAttribute('data-ad-slot') ||
                                    el.hasAttribute('data-google-query-id');
                
                if (hasAdIndicator || el.innerHTML.includes('adsbygoogle')) {
                  el.remove();
                }
              });
            } catch(e) {}
          });
          
          // Remove ad iframes specifically
          document.querySelectorAll('iframe').forEach(function(iframe) {
            var src = iframe.src || '';
            if (src.includes('doubleclick') || 
                src.includes('googlesyndication') || 
                src.includes('adservice') ||
                src.includes('googleadservices') ||
                src.includes('/ads/') ||
                src.includes('ad.php')) {
              iframe.remove();
            }
          });
        }
        
        // Run immediately
        removeGeneralAds();
        
        // Run after delay for lazy-loaded ads
        setTimeout(removeGeneralAds, 1000);
        setTimeout(removeGeneralAds, 2000);
        setTimeout(removeGeneralAds, 3000);
        
        // Watch for new ads being added
        try {
          var observer = new MutationObserver(function(mutations) {
            removeGeneralAds();
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