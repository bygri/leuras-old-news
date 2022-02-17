const pluginFilesMinifier = require('@sherby/eleventy-plugin-files-minifier');
const yaml = require('js-yaml');

module.exports = function(eleventyConfig) {
  eleventyConfig.addPlugin(pluginFilesMinifier);
  eleventyConfig.addDataExtension('yaml', contents => yaml.safeLoad(contents));

  eleventyConfig.addPassthroughCopy('src/static/**');

	return {
    dir: {
      input: 'src',
      output: 'dist'
    }
  }
};
