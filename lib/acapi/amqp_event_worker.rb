require "sneakers"
require "sneakers/runner"
require "sneakers/handlers/maxretry"

module Acapi
  class AmqpEventWorker
    module ProcessPerWorkerWorkerGroup
      include ::Sneakers::WorkerGroup

      def run
        after_fork

        # Allocate single thread pool if share_threads is set. This improves load balancing
        # when used with many workers.
        pool = config[:share_threads] ? Concurrent::FixedThreadPool.new(config[:threads]) : nil

        worker_classes = config[:worker_classes]

        if worker_classes.respond_to? :call
          worker_classes = worker_classes.call
        end

        # If we don't provide a connection to a worker,
        # the queue used in the worker will create a new one

        worker_class = worker_classes[@worker_id]

        Process.setproctitle("[Acapi::AmqpEventWorker] " + worker_class.name)

        @workers  = [
          worker_class.new(nil, pool, { connection: config[:connection] })
        ]

        # if more than one worker this should be per worker
        # accumulate clients and consumers as well
        @workers.each do |worker|
          worker.run
        end
        # end per worker
        #
        until @stop_flag.wait_for_set(Sneakers::CONFIG[:amqp_heartbeat])
          Sneakers.logger.debug("Heartbeat: running threads [#{Thread.list.count}]")
          # report aggregated stats?
        end
      end
    end

    class OneWorkerPerProcessRunner < ::Sneakers::Runner
      def initialize(worker_classes, opts={})
        super(worker_classes, opts)
        @worker_count = worker_classes.length
      end

      def run
        @se = ServerEngine.create(nil, ::Acapi::AmqpEventWorker::ProcessPerWorkerWorkerGroup) { reload_runner_config! }
        @se.run
      end

      def reload_runner_config!
        @runnerconfig.reload_config!.merge({
          :workers => @worker_count
        })
      end
    end

    def self.run
      Rails.application.config.acapi.register_amqp_workers!
      pid_file_location = File.join(File.expand_path(Rails.root), "pids", "sneakers.pid")
      worker_classes = Rails.application.config.acapi.sneakers_worker_classes
      ensure_messaging_exchanges
      Sneakers.configure(
        :workers => worker_classes.length,
        :amqp => Rails.application.config.acapi.remote_broker_uri,
        :start_worker_delay => 0.2,
        :heartbeat => 5,
        :log => STDOUT,
        :pid_path => pid_file_location,
        :handler => Sneakers::Handlers::Maxretry,
        :ack => true,
        :timeout_job_after => 86400,
        :retry_max_times => 5,
        :retry_timeout => 5000
      )
      Sneakers.logger.level = Logger::INFO
      runner = OneWorkerPerProcessRunner.new(worker_classes)
      # runner = Sneakers::Runner.new(worker_classes)
      runner.run
    end

    def self.ensure_messaging_exchanges
      ::Acapi::Amqp::MessagingExchangeTopology.ensure_topology_exists(Rails.application.config.acapi.remote_broker_uri)
    end
  end
end
