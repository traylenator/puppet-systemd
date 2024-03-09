# @summary
#   Helper to define timer and accompanying services for a given task (cron like interface).
# @param ensure whether the timer and service should be present or absent
# @param command the command for the systemd servie to execute
# @param user the user to run the command as
# @param on_active_sec run service relative to the time when the timer was activated
# @param on_boot_sec run service relative to when the machine was booted
# @param on_start_up_sec run service relative to when the service manager was started
# @param on_unit_active_sec run service relative to when the unit was last activated
# @param on_unit_inactive_sec run service relative to when the unit was last deactivated
# @param on_calendar the calendar event expressions time to run the service
# @param service_overrides override for the`[Service]` section of the service
# @param timer_overrides override for the`[Timer]` section of the timer
# @param service_unit_overrides override for the`[Unit]` section of the service
# @param timer_unit_overrides override for the `[Unit]` section of the timer
# @example Create a timer that runs every 5 minutes
#   systemd::timer_wrapper { 'my_timer':
#     ensure        => 'present',
#     command       => '/usr/bin/echo "Hello World"',
#     on_calendar   => '*:0/5',
#   }
# @example Create a timer with overrides for the service and timer
#   systemd::timer_wrapper { 'my_timer':
#     ensure             => 'present',
#     command            => '/usr/bin/echo "Hello World"',
#     on_calendar        => '*:0/5',
#     service_overrides => { 'Group' => 'nobody' },
#     timer_overrides   => { 'OnBootSec' => '10' },
#   }
# @example Create a timer with overrides for the service_unit and timer_unit
#   systemd::timer_wrapper { 'my_timer':
#     ensure                 => 'present',
#     command                => '/usr/bin/echo "Hello World"',
#     on_calendar            => '*:0/5',
#     service_unit_overrides => { 'Wants' => 'network-online.target' },
#     timer_unit_overrides   => { 'Description' => 'Very special timer' },
#   }
define systemd::timer_wrapper (
  Enum['present', 'absent']              $ensure,
  Optional[Systemd::Unit::Service::Exec] $command = undef,
  Optional[String[1]]                    $user = undef,
  Optional[Systemd::Unit::Timespan]      $on_active_sec = undef,
  Optional[Systemd::Unit::Timespan]      $on_boot_sec = undef,
  Optional[Systemd::Unit::Timespan]      $on_start_up_sec = undef,
  Optional[Systemd::Unit::Timespan]      $on_unit_active_sec = undef,
  Optional[Systemd::Unit::Timespan]      $on_unit_inactive_sec = undef,
  Optional[Systemd::Unit::Timespan]      $on_calendar = undef,
  Optional[Systemd::Unit::Service]       $service_overrides = undef,
  Optional[Systemd::Unit::Timer]         $timer_overrides = undef,
  Optional[Systemd::Unit::Unit]          $timer_unit_overrides = undef,
  Optional[Systemd::Unit::Unit]          $service_unit_overrides = undef,
) {
  $_timer_spec = {
    'OnActiveSec'       => $on_active_sec,
    'OnBootSec'         => $on_boot_sec,
    'OnStartUpSec'      => $on_start_up_sec,
    'OnUnitActiveSec'   => $on_unit_active_sec,
    'OnUnitInactiveSec' => $on_unit_inactive_sec,
    'OnCalendar'        => $on_calendar,
  }.filter |$k, $v| { $v =~ NotUndef }

  if $ensure == 'present' {
    if $_timer_spec == {} {
      fail('At least one of on_active_sec,
        on_boot_sec,
        on_start_up_sec,
        on_unit_active_sec,
        on_unit_inactive_sec,
        or on_calendar must be set'
      )
    }
    if ! $command {
      fail('command must be set')
    }
  }

  $_service = {
    'ExecStart' => $command, # if ensure present command is defined is checked above
    'User'      => $user, # defaults apply
    'Type'      => 'oneshot',
  }.filter |$k, $v| { $v =~ NotUndef }

  $service_ensure = $ensure ? { 'absent' => false,  default  => true, }
  $unit_name = systemd::escape($title)

  $_service_unit_entry = $service_unit_overrides ? {
    Undef   => undef,
    default => $service_unit_overrides,
  }

  $_service_entry = $service_overrides ? {
    Undef   => $_service,
    default => $_service + $service_overrides
  }

  systemd::manage_unit { "${unit_name}.service":
    ensure        => $ensure,
    unit_entry    => $_service_unit_entry,
    service_entry => $_service_entry,
  }

  $_timer_unit_entry = $timer_unit_overrides ? {
    Undef   => undef,
    default => $timer_unit_overrides,
  }

  $_timer_entry = $timer_overrides ? {
    Undef   => $_timer_spec,
    default => $_timer_spec + $timer_overrides,
  }

  systemd::manage_unit { "${unit_name}.timer":
    ensure        => $ensure,
    unit_entry    => $timer_unit_overrides,
    timer_entry   => $_timer_entry,
    install_entry => {
      'WantedBy' => 'timers.target',
    },
  }

  service { "${unit_name}.timer":
    ensure => $service_ensure,
    enable => $service_ensure,
  }

  if $ensure == 'present' {
    Systemd::Manage_unit["${unit_name}.service"]
    -> Systemd::Manage_unit["${unit_name}.timer"]
    -> Service["${unit_name}.timer"]
  } else {
    # Ensure the timer is stopped and disabled before the service
    Service["${unit_name}.timer"]
    -> Systemd::Manage_unit["${unit_name}.timer"]
    -> Systemd::Manage_unit["${unit_name}.service"]
  }
}
