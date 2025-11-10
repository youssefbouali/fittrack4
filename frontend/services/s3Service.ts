import Amplify, { Storage as AmplifyStorage } from 'aws-amplify';

export const S3Service = {
  async uploadFile(file: File, fileName: string): Promise<{ key: string; url: string }> {
    const result: any = await AmplifyStorage.put(fileName, file, {
      contentType: file.type,
      level: 'public',
    });

    return {
      key: result.key,
      url: await this.getFileUrl(result.key),
    };
  },

  async getFileUrl(key: string): Promise<string> {
    const url: any = await AmplifyStorage.get(key, { level: 'public', expires: 3600 });
    return url as string;
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
