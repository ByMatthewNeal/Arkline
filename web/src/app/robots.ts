import type { MetadataRoute } from 'next';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/dashboard/', '/api/', '/payment-success', '/reset-password', '/renew'],
      },
    ],
    sitemap: 'https://arkline.io/sitemap.xml',
  };
}
