const withPWA = require('next-pwa')({
  dest: 'public',
  register: true,
  skipWaiting: true,
  disable: process.env.NODE_ENV === 'development',
  // Runtime caching for essential assets
  runtimeCaching: [
    {
      urlPattern: /^https:\/\/fonts\.(?:gstatic|googleapis)\.com\/.*/i,
      handler: 'CacheFirst',
      options: { cacheName: 'google-fonts', expiration: { maxEntries: 20, maxAgeSeconds: 60*60*24*365 } }
    },
    {
      urlPattern: /\.(?:eot|otf|ttc|ttf|woff|woff2|font\.css)$/i,
      handler: 'StaleWhileRevalidate',
      options: { cacheName: 'static-font-assets' }
    },
    {
      urlPattern: /\.(?:jpg|jpeg|gif|png|svg|ico|webp)$/i,
      handler: 'StaleWhileRevalidate',
      options: { cacheName: 'static-image-assets' }
    },
    // Cache API responses for offline support
    {
      urlPattern: /\/(api|transactions|budgets|goals)\/.*.*/i,
      handler: 'NetworkFirst',
      options: { cacheName: 'api-responses', expiration: { maxEntries: 50, maxAgeSeconds: 60*60*24 } }
    },
    // Cache essential page assets for offline
    {
      urlPattern: '^/_(next|metatags|data)-',
      handler: 'StaleWhileRevalidate',
      options: { cacheName: 'page-assets', expiration: { maxEntries: 100, maxAgeSeconds: 60*60*24*7 } }
    }
  ]
});

/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
};

module.exports = withPWA(nextConfig);
