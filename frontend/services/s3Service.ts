import { Storage as AmplifyStorage } from '@aws-amplify/storage';

export const S3Service = {
  async uploadFile(file: File, fileName: string): Promise<{ key: string; url: string }> {
    const result = await AmplifyStorage.put(fileName, file, {
      contentType: file.type,
      level: 'public',
    });

    return {
      key: result.key,
      url: await this.getFileUrl(result.key),
    };
  },

  async getFileUrl(key: string): Promise<string> {
    return AmplifyStorage.get(key, {
      level: 'public',
      expires: 3600,
    }) as Promise<string>;
  },

  async deleteFile(key: string): Promise<void> {
    await AmplifyStorage.remove(key, { level: 'public' });
  },

  generateFileName(userId: string, fileExtension: string): string {
    const timestamp = Date.now();
    const randomString = Math.random().toString(36).substring(7);
    return `activities/${userId}/${timestamp}-${randomString}.${fileExtension}`;
  },
};
