class IOS < Base
  ACC_ID = 'AccessibilityId'
  IDENTIFIER = 'identifier'
  LABEL = 'label'
  NSPREDICATE = 'iOSNsPredicateString'

  attr_accessor :platform, :udid, :bundle_id, :ios_sim, :dir

  def initialize(options)
    self.platform = options[:platform]
    self.udid = options[:udid]
    self.ios_sim = options[:ios_sim]
    self.bundle_id = options[:bundle_id]
    self.dir = options[:dir]
  end

  def skeletoner
    create_page_objects(page_source)
  end

  private

  def create_locator(line)
    locator_by_id = locator_by_id(line)
    locator_by_label = locator_by_label(line)
    if !locator_by_id.empty?
      create_locator_by_id(locator_by_id)
    elsif !locator_by_label.empty?
      type = element_type(line)
      create_locator_by_label(locator_by_label, type)
    end
  end

  def create_locator_by_id(locator)
    method_name = locator.strip
    code_generation(method_name, ACC_ID, locator)
  end

  def create_locator_by_label(locator, type)
    @@locator_index += 1
    method_name = "#{type}#{@@locator_index}"
    locator = "#{LABEL} like '#{locator}'"
    code_generation(method_name, NSPREDICATE, locator)
  end

  def create_page_objects(page_source)
    page_source.each_line do |line|
      break if line.include?(' StatusBar, ')
      next  if line.include?('Application, ')
      create_locator(line)
    end
  end

  def element_type(line)
    line_first_word = line.split.first
    line_first_word.nil? ? '' : line_first_word.chomp(',')
  end

  def locator_by_id(line)
    locator = /#{IDENTIFIER}: '(.*?)'/.match(line)
    locator.nil? ? '' : locator[1]
  end

  def locator_by_label(line)
    locator = /#{LABEL}: '(.*?)'/.match(line)
    locator.nil? ? '' : locator[1]
  end

  def code_generation(method_name, locator_type, value)
    java = java(method_name, locator_type, value)
    add_new_page_object(java, Language::RUBY)

    # ADD OTHER LANGUAGES HERE
  end

  def java(method_name, locator_type, value)
    <<~JAVA
      By #{camel_style(method_name)}() {
        return MobileBy.#{locator_type}("#{value}");
      }

    JAVA
  end

  def add_new_page_object(code, lan)
    File.open("#{@dir}/#{@platform}_#{TIMESTAMP}.#{lan}", 'a') do |f|
      f.write(code)
    end
  end

  def page_source
    ios_arch = @ios_sim ? 'iOS Simulator' : 'iOS'
    %x(xcodebuild test \
      -project Skeleton.xcodeproj \
      -scheme Skeleton \
      -destination 'platform=#{ios_arch},id=#{@udid}' \
      bundle_id="#{@bundle_id}" | \
      awk '/start_grep_tag/,/end_grep_tag/')
  end
end