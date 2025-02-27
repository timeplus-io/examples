const DEFAULT_ENV: Env = {
  host: 'http://localhost',
  tenant: null,
  apiKey: null,
  username: null,
  password: null,
  target: 'onprem'
}

let currentEnv: Env = DEFAULT_ENV;

export interface Env {
  /**
   * Host address of the Timeplus server. Make sure you include the scheme (http or https)
   * e.g. https://us.timeplus.cloud or http://localhost
   */
  host: string | undefined;

  /**
   * Port number
   */
  port?: number;

  /**
   * Tenant ID (for cloud only)
   */
  tenant: string | null | undefined;

  /**
   * Api key (for cloud only)
   */
  apiKey: string | null | undefined;

  /**
   * Username (for onprem only)
   */
  username: string | null | undefined;

  /**
   * Password (for onprem only)
   */
  password: string | null | undefined;

  /**
   * Whether it is Timeplus Enterprise Cloud or Timeplus Enterprise (self-hosted)
   */
  target: 'onprem' | 'cloud';
}

export const SetEnv = (env: Env) => {
  currentEnv = env;
}

export const Env = () => {
  return {
    BuildUrl(apiVersion: string, resourceName: string): string {
      let url = currentEnv.host;
      if (currentEnv.port) {
        url += `:${currentEnv.port}`;
      }
      const paths = [url];
      if (currentEnv.tenant) {
        paths.push(currentEnv.tenant)
      }
      paths.push('api', apiVersion, resourceName)
      return paths.join('/');
    },
    AuthHeader(): object {
      if (currentEnv.target === 'cloud' && currentEnv.apiKey) {
        return {
          'X-Api-Key': currentEnv.apiKey
        }
      }
      if (currentEnv.target === 'onprem' && currentEnv.username) {
        const token = `${currentEnv.username}:${currentEnv.password}`
        return {
          'Authorization': `Basic ${btoa(token)}`
        }
      }
      return { }
    }
  }
}
