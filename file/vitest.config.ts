import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'clarinet',
    environmentOptions: {
      clarinet: {
        coverage: false  // Disable coverage since it's causing issues
      }
    },
    globals: true,
    setupFiles: ['./tests/setup.ts']
  }
})
