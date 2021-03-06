from fabric.api import execute, local

def b():
    '''
    Build.
    '''
    local('swift build')

def r():
    '''
    Run.
    '''
    local('.build/debug/leurasoldnews fetch 1881608')

def c():
    '''
    Clean build directory.
    '''
    local('rm -rf .build')

def cp():
    '''
    Clean Packages directory.
    '''
    local('rm -rf Packages')

def br():
    '''
    Build and run.
    '''
    execute(b)
    execute(r)

def cbr():
    '''
    Clean, build and run.
    '''
    execute(c)
    execute(b)
    execute(r)

def deploy():
    '''
    Send to live site.
    '''
    local('rsync -avz --delete www/ marywadefamily.org:/var/www/leurasoldnews/')
