# @summary Base Sensu class
#
# This is the main Sensu class
#
# @param version
#   Version of Sensu to install.  Defaults to `installed` to support
#   Windows MSI packaging and to avoid surprising upgrades.
#
# @param etc_dir
#   Absolute path to the Sensu etc directory.
#
# @param ssl_dir
#   Absolute path to the Sensu ssl directory.
#
# @param user
#   User used by sensu services
#
# @param group
#   User group used by sensu services
#
# @param etc_dir_purge
#   Boolean to determine if the etc_dir should be purged
#   such that only Puppet managed files are present.
#
# @param ssl_dir_purge
#   Boolean to determine if the ssl_dir should be purged
#   such that only Puppet managed files are present.
#
# @param manage_repo
#   Boolean to determine if software repository for Sensu
#   should be managed.
#
# @param use_ssl
#   Sensu backend service uses SSL
#
# @param ssl_ca_source
#   Source of SSL CA used by sensu services
#
class sensu (
  String $version = 'installed',
  Stdlib::Absolutepath $etc_dir = '/etc/sensu',
  Stdlib::Absolutepath $ssl_dir = '/etc/sensu/ssl',
  String $user = 'sensu',
  String $group = 'sensu',
  Boolean $etc_dir_purge = true,
  Boolean $ssl_dir_purge = true,
  Boolean $manage_repo = true,
  Boolean $use_ssl = true,
  Optional[String] $ssl_ca_source = $facts['puppet_localcacert'],
) {

  if $use_ssl and ! $ssl_ca_source {
    fail('sensu: ssl_ca_source must be defined when use_ssl is true')
  }

  if $facts['os']['family'] == 'windows' {
    $sensu_user = undef
    $sensu_group = undef
    $file_mode = undef
    $trusted_ca_file_path = "${ssl_dir}\\ca.crt"
    $agent_config_path = "${etc_dir}\\agent.yml"
  } else {
    $sensu_user = $user
    $sensu_group = $group
    $file_mode = '0640'
    $join_path = '/'
    $trusted_ca_file_path = "${ssl_dir}/ca.crt"
    $agent_config_path = "${etc_dir}/agent.yml"
  }

  file { 'sensu_etc_dir':
    ensure  => 'directory',
    path    => $etc_dir,
    purge   => $etc_dir_purge,
    recurse => $etc_dir_purge,
    force   => $etc_dir_purge,
  }

  if $use_ssl {
    contain ::sensu::ssl
  }

  case $facts['os']['family'] {
    'RedHat': {
      $os_package_require = []
    }
    'Debian': {
      $os_package_require = [Class['::apt::update']]
    }
    'windows': {
      $os_package_require = []
    }
    default: {
      fail("Detected osfamily <${facts['os']['family']}>. Only RedHat, Debian and Windows are supported.")
    }
  }

  # $package_require is used by sensu::agent and sensu::backend
  # package resources
  if $manage_repo {
    include ::sensu::repo
    $package_require = [Class['::sensu::repo']] + $os_package_require
  } else {
    $package_require = undef
  }

}
