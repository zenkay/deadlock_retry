module DeadlockRetry

  def self.included(base)
    base.extend(ClassMethods)
    base.class_eval do
      class << self
        alias_method_chain :transaction, :deadlock_handling
      end
    end
  end

  module ClassMethods
    DEADLOCK_ERROR_MESSAGES = [
      "Deadlock found when trying to get lock",
      "Lock wait timeout exceeded"
    ]

    MAXIMUM_RETRIES_ON_DEADLOCK = 3

    def transaction_with_deadlock_handling(*objects, &block)
      retry_count = 0

      begin
        transaction_without_deadlock_handling(*objects, &block)
      rescue ActiveRecord::StatementInvalid => error
        raise if in_nested_transaction?
        if DEADLOCK_ERROR_MESSAGES.any? { |msg| error.message =~ /#{Regexp.escape(msg)}/ }
          raise if retry_count >= MAXIMUM_RETRIES_ON_DEADLOCK
          retry_count += 1
          logger.info "Deadlock detected on retry #{retry_count}, restarting transaction"
          log_innodb_status
          retry
        else
          raise
        end
      end
    end

    private

    def in_nested_transaction?
      # open_transactions was added in 2.2's connection pooling changes.
      connection.open_transactions != 0
    end

    def log_innodb_status
      # show innodb status is the only way to get visiblity into why
      # the transaction deadlocked.  log it.
      lines = connection.select_value("show innodb status")
      logger.warn "INNODB Status follows:"
      lines.each_line do |line|
        logger.warn line
      end
    rescue Exception => e
      # Access denied, ignore
      logger.warn "Cannot log innodb status: #{e.message}"
    end

  end
end

ActiveRecord::Base.send(:include, DeadlockRetry)