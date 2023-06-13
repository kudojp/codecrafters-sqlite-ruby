module Database
  class HeaderInfo
    attr_reader :page_size

    def initialize(page_size:)
      @page_size = page_size
    end
  end
end
