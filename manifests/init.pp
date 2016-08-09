# Copyright (C) 2016 OSiRIS Project, funded by the NSF
# Apache License 2.0

#
# == Class: rancid
# Only tested on RHEL derivatives.  
#
# Install and configure rancid
# If using this class with a remote SVN or git repo you must setup passwordless/cached credentials for rancid user to access network repo.
# For example: To use github setup a passwordless ssh key under 'rancid' user and add public key to repo.  Login once manually as user to cache the host key. 
#
# === Parameters:
#
# [*datadir*] Where the rcs repository is stored (BASEDIR in rancid.conf)
# [*logdir*] Log location
# [*rcs*] Revision control system to use.  One of git, svn, or cvs.  Git or Svn can be remote repositories set by rcs_url.  
# [*rcs_url*] Remote URL for repository.  Only relevant to git or svn.  If not specified a local repo under $datadir/$rcs is used.  Must be in URL form like ssh://github.com/user/repo.git (varies by repo).  
#             If it is a remote git repo, the repository must be setup manually as a shared bare repo and rancid-cvs will clone it locally using the URL.  
# [*rcs_auth*] If set to 'sshkey' we won't try to run rancid-cvs until $datadir/.ssh/id_rsa or id_dsa exists.  
#   If a key does not exist we will generate one as well.  It's up to the user to configure the remote repository to accept it.
#   Other values ignored (ideally we should be checking for cached creds if set to 'cached').
# [*groups*] Rancid groups and email aliases.  Should be hash of { 'group' => { 'admin' => 'admin_email@domain','diff' => 'diff_email@domain'}.  Default is a group 'rancid' that sends both email reports to root.   

class rancid (
  $datadir = '/var/rancid',
  $logdir = "/var/log/rancid",
  $rcs = 'git', 
  $rcs_url = undef,
  $rcs_auth = 'sshkey',
  $manage_cloginrc = false,
  $groups = { 'rancid' => { 'admin' => 'root','diff' => 'root' } }  
  ) {

  package {'rancid':
    ensure => present,
    before => File["$datadir"]
  }

  file { "$datadir":
    owner => 'rancid',
    group => 'rancid',
    ensure => 'directory',
    before => User['rancid']
  }

  user { 'rancid': 
    home => $datadir
  }

  file { 'rancidconf':
    path => '/etc/rancid/rancid.conf',
    owner => 'rancid',
    group => 'rancid',
    ensure => present,
    content => template("rancid/rancid.conf.erb"),
  }

  # This should be part of an updated rancid package...and this path may not apply to non RHEL packages?
  file { 'rancid-cvs':
    path => '/usr/libexec/rancid/rancid-cvs',
    owner => 'rancid',
    group => 'rancid',
    mode => 0755,
    ensure => present,
    content => file("rancid/rancid-cvs"),
  }

  if ($manage_cloginrc) {
    file { 'cloginrc': 
        path => "${datadir}/.cloginrc",
        owner => 'rancid',
        group => 'rancid',
        mode => 0600,
        ensure => present,
    }
  }

  if ($rcs_auth == 'sshkey') {
    $auth_key = "/bin/test -f ${datadir}/.ssh/id_*sa" 
    $known_hosts = "/bin/test -f ${datadir}/.ssh/known_hosts" 

    # Problem:  rancid-cvs is not smart about stopping if git clone fails. Short of making it smarter we need 
    # to try and avoid running rancid-cvs until access is configured.  
    # (recovery is easy though, just delete group directory under rancid BASEDIR)
    # exec { 'rancid-keygen': 
    #     command => "/bin/su - rancid -c \"/usr/bin/ssh-keygen -t rsa -f ${rancid::datadir}/.ssh/id_rsa -N '' -q\"",
    #     creates => "${rancid::datadir}/.ssh/id_rsa",
    #     notify => Exec['keygen-notice']
    # }

    # there is not a way to do this with a notify resource (?)
    Exec { 'keygen-notice': 
      command => "/bin/echo -e \"Please generate an ssh key for the rancid user and copy 
      ${datadir}/.ssh/id_rsa.pub to configure your git/svn repository so the rancid user can login.\n
      Test the login manually and run puppet again to initialize the repository contents (the repository 
      itself must be created manually).\nIf you have created the key and are still getting this notice be 
      sure you have tested the login manually and ${datadir}/.ssh/ \"",

      unless => [ $auth_key, $known_hosts ],
      logoutput => true 
    }
  } else {
    $auth_key = true
  }

  $groups.each |$group, $email| {

    mailalias { "rancid-$group" :
      ensure    => present,
      recipient => $email['diff'],
      target    => '/etc/aliases'
    }

    mailalias { "rancid-admin-$group" :
      ensure    => present,
      recipient => $email['admin'],
      target    => '/etc/aliases'
    }

    exec { 'rancid-cvs':  
      command => '/bin/su - rancid -c /bin/rancid-cvs',
      unless => "/bin/test -d ${datadir}/${group}",
      onlyif => $auth_key,
      require => [ File['rancidconf'], File['rancid-cvs'] ]
    }
  }
}

