from invoke import task


@task
def eleventy_build(c):
  c.run('npm install --include=dev\nnpx @11ty\/eleventy', pty=True)

@task
def eleventy_clean(c):
  c.run('rm -r dist', pty=True)

@task
def eleventy_run(c):
  c.run('npm install --include=dev\nnpx @11ty\/eleventy --serve', pty=True)


@task
def docker_build(c):
  if len(c.run('git status --porcelain').stdout):
    print('There are uncommitted changes in the working directory.')
    return
  repo_name = 'asia.gcr.io/tobygriffin/leurasoldnews'
  tag_name = c.run('git rev-parse --short HEAD').stdout[:-1]
  image_name = repo_name + ':' + tag_name
  c.run(
    'docker buildx build --platform linux/amd64 '
    '--push -t {} .'.format(image_name))
