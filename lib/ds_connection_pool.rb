# API's to run queries with connection from the respective connection pool.

module DsConnectionPool
  include ::AvailableDataSource

  def get_connection_pool(ds_type, connection_closure)
    connection_pool_size = ENV.fetch("CONNECTION_POOL_SIZE", 5).to_i
    connection_timeout = ENV.fetch("CONNECTION_TIMEOUT", 5).to_i
    if source_type_supported?(ds_type)
      $connection_pools.fetch_or_store(
        ds_type,
        make_connection_pool(connection_pool_size, connection_timeout, connection_closure)
      )
    else
      raise AvailableDataSource::UnSupportedSource.new
    end
  end

  def with_connection(ds_type, connection_closure)
    conn_pool = get_connection_pool(ds_type, connection_closure)
    conn_pool.with do |conn|
      if block_given?
        yield(conn)
      end
    end
  end

  # Resets the connection pool of a particular source for the current process.
  # If no ds_type is passed, resets the global variable to a new concurrent_map
  def reset_connection_pool!(ds_type = nil)
    if ds_type
      if source_type_supported?(ds_type)
        $connection_pools.delete(ds_type)
      else
        raise AvailableDataSource::UnSupportedSource.new
      end
    else
      $connection_pools = Concurrent::Map.new
    end
  end

  private

  def make_connection_pool(connection_pool_size, connection_timeout, connection_closure)
    ConnectionPool.new(size: connection_pool_size,
                       timeout: connection_timeout) { connection_closure.call() }
  end
end