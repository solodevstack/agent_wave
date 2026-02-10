import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  /* config options here */
  turbopack: {
    root: process.cwd(), // Fix the turbopack warning
  },
  images: {
    qualities: [100],
    remotePatterns: [
      // Allow images from your own domain (for Walrus CDN)
      {
        protocol: 'https',
        hostname: '**.vercel.app',
      },
      {
        protocol: 'http',
        hostname: 'localhost',
        port: '3000',
      },
      // Keep existing Walrus aggregators as fallback
      {
        protocol: 'https',
        hostname: 'aggregator.walrus-testnet.walrus.space',
      },
      {
        protocol: 'https',
        hostname: '**.walrus.space',
      },
      // BlockBerry aggregator (if you use it)
      {
        protocol: 'https',
        hostname: 'aggregator.blockberry.one',
      },
      {
        protocol: 'https',
        hostname: 'escrowave-u5up.vercel.app',
      },
    ],
  },
  webpack: (config, { isServer }) => {
    // Handle WASM files
    config.experiments = {
      ...config.experiments,
      asyncWebAssembly: true,
      layers: true,
    };

    return config;
  },
  // Remove WASM from server external packages - let it bundle but don't execute
  serverExternalPackages: [],
  
  // Add proxy rewrites for Walrus aggregators AND publishers
  async rewrites() {
    // Real Walrus testnet aggregator endpoints
    const walrusAggregators = [
      'https://aggregator.walrus-testnet.walrus.space',
      'https://wal-aggregator-testnet.staketab.org',
      'https://walrus-testnet-aggregator.bartestnet.com',
      'https://walrus-testnet.blockscope.net',
      'https://walrus-testnet-aggregator.nodes.guru',
      'https://walrus-cache-testnet.overclock.run',
    ];

    // Real Walrus testnet publisher endpoints
    const walrusPublishers = [
      'https://publisher.walrus-testnet.walrus.space',
      'https://wal-publisher-testnet.staketab.org',
      'https://walrus-testnet-publisher.bartestnet.com',
      'https://walrus-testnet.blockscope.net',
      'https://walrus-testnet-publisher.nodes.guru',
      'https://walrus-publisher-testnet.overclock.run',
    ];

    return [
      // Aggregator proxies
      {
        source: '/aggregator1/:path*',
        destination: `${walrusAggregators[0]}/:path*`,
      },
      {
        source: '/aggregator2/:path*',
        destination: `${walrusAggregators[1]}/:path*`,
      },
      {
        source: '/aggregator3/:path*',
        destination: `${walrusAggregators[2]}/:path*`,
      },
      {
        source: '/aggregator4/:path*',
        destination: `${walrusAggregators[3]}/:path*`,
      },
      {
        source: '/aggregator5/:path*',
        destination: `${walrusAggregators[4]}/:path*`,
      },
      {
        source: '/aggregator6/:path*',
        destination: `${walrusAggregators[5]}/:path*`,
      },
      // Publisher proxies
      {
        source: '/publisher1/:path*',
        destination: `${walrusPublishers[0]}/:path*`,
      },
      {
        source: '/publisher2/:path*',
        destination: `${walrusPublishers[1]}/:path*`,
      },
      {
        source: '/publisher3/:path*',
        destination: `${walrusPublishers[2]}/:path*`,
      },
      {
        source: '/publisher4/:path*',
        destination: `${walrusPublishers[3]}/:path*`,
      },
      {
        source: '/publisher5/:path*',
        destination: `${walrusPublishers[4]}/:path*`,
      },
      {
        source: '/publisher6/:path*',
        destination: `${walrusPublishers[5]}/:path*`,
      },
    ];
  },
};

export default nextConfig;