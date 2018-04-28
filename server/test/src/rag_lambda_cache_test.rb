require_relative 'test_base'
require_relative '../../src/rag_lambda_cache'

class RagLambdaCacheTest < TestBase

  def self.hex_prefix
    '332FC'
  end

  def hex_setup
    @cache = RagLambdaCache.new
  end

  # - - - - - - - - - - - - - - - -

  test '6CC',
  'block is used to populate the cache once only' do
    @count = 0
    5.times {
      ragger = @cache.rag_lambda('gcc_assert') { @count += 1; eval(purple) }
      assert_equal :purple, ragger.call('stdout','stderr',status=23)
    }
    assert_equal 1, @count
  end

  # - - - - - - - - - - - - - - - -

  def purple
    <<~RUBY
    lambda { |stdout, stderr, status|
      return :purple
    }
    RUBY
  end

end
