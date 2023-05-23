scope: postgres-cluster
name: ${id}
namespace: /

restapi:
  listen: 0.0.0.0:8008
  connect_address: ${ip}:8008
#  certfile: /etc/ssl/certs/ssl-cert-snakeoil.pem
#  keyfile: /etc/ssl/private/ssl-cert-snakeoil.key
#  authentication:
#    username: username
#    password: password

consul:
  host: 127.0.0.1:8500
  checks: []
  register_service: true

bootstrap:
  method: initdb
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    master_start_timeout: 300
    synchronous_mode: true
    synchronous_mode_strict: false
    synchronous_node_count: 1
    postgresql:
      use_pg_rewind: true
      use_slots: true
      parameters:
        max_connections: 500
        superuser_reserved_connections: 5
        password_encryption: md5
#        password_encryption: scram-sha-256
        max_locks_per_transaction: 64
        max_prepared_transactions: 0
        huge_pages: try
        shared_buffers: 244MB
        effective_cache_size: 732MB
        work_mem: 128MB
        maintenance_work_mem: 256MB
        checkpoint_timeout: 15min
        checkpoint_completion_target: 0.9
        min_wal_size: 2GB
        max_wal_size: 8GB
        wal_buffers: 32MB
        default_statistics_target: 1000
        seq_page_cost: 1
        random_page_cost: 4
        effective_io_concurrency: 2
        synchronous_commit: on
        autovacuum: on
        autovacuum_max_workers: 5
        autovacuum_vacuum_scale_factor: 0.01
        autovacuum_analyze_scale_factor: 0.01
        autovacuum_vacuum_cost_limit: 500
        autovacuum_vacuum_cost_delay: 2
        autovacuum_naptime: 1s
        max_files_per_process: 4096
        archive_mode: on
        archive_timeout: 1800s
        archive_command: cd .
        wal_level: replica
        wal_keep_size: 2GB
        max_wal_senders: 10
        max_replication_slots: 10
        hot_standby: on
        wal_log_hints: on
        wal_compression: on
        shared_preload_libraries: pg_stat_statements,auto_explain
        pg_stat_statements.max: 10000
        pg_stat_statements.track: all
        pg_stat_statements.track_utility: false
        pg_stat_statements.save: true
        auto_explain.log_min_duration: 10s
        auto_explain.log_analyze: true
        auto_explain.log_buffers: true
        auto_explain.log_timing: false
        auto_explain.log_triggers: true
        auto_explain.log_verbose: true
        auto_explain.log_nested_statements: true
        auto_explain.sample_rate: 0.01
        track_io_timing: on
        log_lock_waits: on
        log_temp_files: 0
        track_activities: on
        track_counts: on
        track_functions: all
        log_checkpoints: on
        logging_collector: on
        log_truncate_on_rotation: on
        log_rotation_age: 1d
        log_rotation_size: 0
        log_line_prefix: '%t [%p-%l] %r %q%u@%d '
        log_filename: postgresql-%a.log
        log_directory: /var/log/postgresql
        hot_standby_feedback: on
        max_standby_streaming_delay: 30s
        wal_receiver_status_interval: 10s
        idle_in_transaction_session_timeout: 10min
        jit: off
        max_worker_processes: 24
        max_parallel_workers: 8
        max_parallel_workers_per_gather: 2
        max_parallel_maintenance_workers: 2

  initdb:  # List options to be passed on to initdb
    - encoding: UTF8
    - locale: en_US.UTF-8
    - data-checksums

  pg_hba:  # Add following lines to pg_hba.conf after running 'initdb'
    - host replication replicator 0.0.0.0/0 md5
    - host all all 0.0.0.0/0 md5

postgresql:
  listen: 0.0.0.0:5432
  connect_address: ${ip}:5432
  use_unix_socket: true
  data_dir: /var/lib/postgresql/14/main
  bin_dir: /usr/lib/postgresql/14/bin
  config_dir: /etc/postgresql/14/main
  pgpass: /var/lib/postgresql/.pgpass_patroni
  authentication:
    replication:
      username: replicator
      password: replicator-pass
    superuser:
      username: postgres
      password: postgres-pass
  #    rewind:  # Has no effect on postgres 10 and lower
  #      username: rewind_user
  #      password: rewind_password
  parameters:
    unix_socket_directories: /var/run/postgresql

  remove_data_directory_on_rewind_failure: false
  remove_data_directory_on_diverged_timelines: false

  create_replica_methods:
    - basebackup
  basebackup:
    max-rate: '100M'
    checkpoint: 'fast'

watchdog:
  mode: automatic  # Allowed values: off, automatic, required
  device: /dev/watchdog  # Path to the watchdog device
  safety_margin: 5

tags:
  nofailover: false
  noloadbalance: false
  clonefrom: false
  nosync: false

# specify a node to replicate from (cascading replication)
#  replicatefrom: (node name)
