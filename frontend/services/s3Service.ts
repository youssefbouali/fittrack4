// For Amplify Gen 2
import { storage } from '@aws-amplify/storage';

export const S3Service = {
  async uploadFile(file: File, fileName: string): Promise<{ key: string; url: string }> {
    await storage.put(fileName, file, {
      level: 'public',
      contentType: file.type,
    });

    const { url } = await storage.getUrl(fileName, { level: 'public' });
    return {
      key: fileName,
      url: url.toString(), // URL is a URL object in Gen 2
    };
  },

  async getFileUrl(key: string): Promise<string> {
    const { url } = await storage.getUrl(key, { level: 'public' });
    return url.toString();
  },

  async deleteFile(key: string): Promise<void> {
    await storage.remove(key, { level: 'public' });
  },

  generateFileName(userId: string, fileExtension: string): string {
    const timestamp = Date.now();
    const randomString = Math.random().toString(36).substring(7);
    return `activities/${userId}/${timestamp}-${randomString}.${fileExtension}`;
  },
};