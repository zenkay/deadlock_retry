require 'rubygems'

# Change the version if you want to test a different version of ActiveRecord
gem 'activerecord', '3.0.7'
require 'active_record'
require 'active_record/version'
puts "Testing ActiveRecord #{ActiveRecord::VERSION::STRING}"

require 'test/unit'
require 'logger'
require "deadlock_retry"

class MockModel
  @@open_transactions = 0

  def self.transaction(*objects)
    @@open_transactions += 1
    yield
  ensure
    @@open_transactions -= 1
  end

  def self.open_transactions
    @@open_transactions
  end

  def self.connection
    self
  end

  def self.logger
    @logger ||= Logger.new(nil)
  end

  include DeadlockRetry

  def self.log_innodb_status
    @logged = true
  end

  def self.was_logged
    @logged
  end

  def self.clear_was_logged
    @logged = false
  end
end

class DeadlockRetryTest < Test::Unit::TestCase
  DEADLOCK_ERROR = "MySQL::Error: Deadlock found when trying to get lock"
  TIMEOUT_ERROR = "MySQL::Error: Lock wait timeout exceeded"

  def setup
    DeadlockRetry.log_innodb_status = false
    MockModel.clear_was_logged
  end

  def test_no_errors
    assert_equal :success, MockModel.transaction { :success }
  end

  def test_no_errors_with_deadlock
    errors = [ DEADLOCK_ERROR ] * 3
    assert_equal :success, MockModel.transaction { raise ActiveRecord::StatementInvalid, errors.shift unless errors.empty?; :success }
    assert errors.empty?
  end

  def test_no_errors_with_lock_timeout
    errors = [ TIMEOUT_ERROR ] * 3
    assert_equal :success, MockModel.transaction { raise ActiveRecord::StatementInvalid, errors.shift unless errors.empty?; :success }
    assert errors.empty?
  end

  def test_error_if_limit_exceeded
    assert_raise(ActiveRecord::StatementInvalid) do
      MockModel.transaction { raise ActiveRecord::StatementInvalid, DEADLOCK_ERROR }
    end
  end

  def test_error_if_unrecognized_error
    assert_raise(ActiveRecord::StatementInvalid) do
      MockModel.transaction { raise ActiveRecord::StatementInvalid, "Something else" }
    end
  end

  def test_included_by_default
    assert ActiveRecord::Base.respond_to?(:transaction_with_deadlock_handling)
  end

  def test_error_in_nested_transaction_should_retry_outermost_transaction
    tries = 0
    errors = 0

    MockModel.transaction do
      tries += 1
      MockModel.transaction do
        MockModel.transaction do
          errors += 1
          raise ActiveRecord::StatementInvalid, "MySQL::Error: Lock wait timeout exceeded" unless errors > 3
        end
      end
    end

    assert_equal 4, tries
  end

  def test_should_not_log_innodb_by_default
    errors = [ DEADLOCK_ERROR ] * 3
    MockModel.transaction { raise ActiveRecord::StatementInvalid, errors.shift unless errors.empty?;}
    assert !MockModel.was_logged
  end

  def test_should_log_if_logging_enabled
    errors = [ DEADLOCK_ERROR ] * 3
    DeadlockRetry.log_innodb_status = true
    MockModel.transaction { raise ActiveRecord::StatementInvalid, errors.shift unless errors.empty?;}
    assert MockModel.was_logged
  end
end
