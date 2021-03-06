class IOS < Base
  ACC_ID = {
    java: :AccessibilityId,
    ruby: :accessibility_id,
    javascript: :id,
    python: :find_element_by_accessibility_id
  }.freeze
  NSPREDICATE = {
    java: :iOSNsPredicateString,
    ruby: :predicate,
    javascript: :predicate,
    python: :find_element_by_ios_predicate
  }.freeze
  IDENTIFIER = 'identifier'.freeze
  LABEL = 'label'.freeze
  XCRESULTS_FOLDER = "#{ROOT_DIR}/XCResults".freeze
  XCODEPROJ_FOLDER = "#{ROOT_DIR}/xcodeproj".freeze

  attr_accessor :udid, :bundle_id

  def initialize(options)
    self.udid = options.udid
    self.bundle_id = options.bundle
    @language = Language.new
  end

  def skeletoner
    check_udid
    check_bundle
    Log.info('We starting to skeleton your screen 🚀')
    page_source
    create_page_objects
    save_screenshot
    save(code: page_source)
    Log.info('We successfully skeletoned your screen 👻')
  end

  def devices
    `idevice_id -l`.split.uniq.map { |d| d }
  end

  private

  def bundle_id=(bundle_id)
    raise 'Not set bundle_id [-b arg]' if bundle_id.nil?
    @bundle_id = bundle_id
  end

  def create_locator(line)
    locator_by_id = locator_by_id(line)
    locator_by_label = locator_by_label(line)
    type = element_type(line)
    if !locator_by_id.empty?
      create_locator_by_id(locator_by_id, type)
    elsif !locator_by_label.empty?
      create_locator_by_label(locator_by_label, type)
    end
  end

  def create_locator_by_id(locator, type)
    method_name = locator.strip
    locator_hash = { locator => type }
    code_generation(method_name: method_name,
                    locator_type: ACC_ID,
                    locator_value: locator_hash,
                    accessibility_id: true)
  end

  def create_locator_by_label(text, type)
    method_name = "#{type}#{increment_locator_id}"
    locator = "#{LABEL} LIKE '#{text}'"
    locator_hash = { locator => type }
    code_generation(method_name: method_name,
                    locator_type: NSPREDICATE,
                    locator_value: locator_hash)
  end

  def create_page_objects
    Log.info('Generation page objects for your awesome language 💪')
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
    if locator.nil?
      ''
    else
      label = locator[1]
      i = 0
      label.each_char do |char|
        if char =~ /(\"|\')/
          new_value = "\\#{char}"
          label[i] = new_value
          i += new_value.length - 1
        end
        i += 1
      end
      label
    end
  end

  def code_generation(method_name:,
                      locator_type:,
                      locator_value:,
                      accessibility_id: false)
    method_name = "_#{method_name}" if method_name[0] =~ /\d+/
    snake_style = snake_style(method_name)
    camel_style = camel_style(method_name)
    java = @language.java(camel_method_name: camel_style,
                          locator_type: locator_type,
                          locator_value: locator_value.keys.first)
    ruby = @language.ruby(snake_method_name: snake_style,
                          locator_type: locator_type,
                          locator_value: locator_value.keys.first)
    python = @language.python(snake_method_name: snake_style,
                              locator_type: locator_type,
                              locator_value: locator_value.keys.first)
    js = @language.js(camel_method_name: camel_style,
                      locator_type: locator_type,
                      locator_value: locator_value.keys.first)
    xcui_element_type = XCUIElement.types[locator_value.values.first.to_sym]
    swift = @language.swift(camel_method_name: camel_style,
                            element_type: xcui_element_type,
                            locator_value: locator_value.keys.first,
                            accessibility_id: accessibility_id)
    save(code: java, format: Language::JAVA)
    save(code: ruby, format: Language::RUBY)
    save(code: python, format: Language::PYTHON)
    save(code: js, format: Language::JAVASCRIPT)
    save(code: swift, format: Language::SWIFT)
  end

  def page_source
    if @page_source.nil?
      Log.info('Getting screen source tree ⚒')
      FileUtils.rm_rf(XCRESULTS_FOLDER)
      start_grep = 'start_grep_tag'
      end_grep = 'end_grep_tag'
      ios_arch = @simulator ? 'iOS Simulator' : 'iOS'
      @page_source = `xcodebuild test \
          -project #{XCODEPROJ_FOLDER}/Skeleton.xcodeproj \
          -scheme Skeleton \
          -destination 'platform=#{ios_arch},id=#{@udid}' \
          -resultBundlePath #{XCRESULTS_FOLDER} \
          bundle_id="#{@bundle_id}" | \
          awk '/#{start_grep}/,/#{end_grep}/'`
      @page_source.slice!(start_grep)
      @page_source.slice!(end_grep)
      if @page_source.empty?
        Log.error("Try to sign Skeleton and SkeletonUI targets in " \
                  "#{XCODEPROJ_FOLDER}/Skeleton.xcodeproj \n" \
                  'For more info read: https://github.com/alter-al/' \
                  'skeleton/blob/master/docs/real-ios-device-config.md')
      end
      Log.info('Successfully getting Screen Source Tree 🔥')
    end
    @page_source
  end

  def check_bundle
    if @simulator
      return if `xcrun simctl appinfo #{@udid} #{@bundle_id}`.include?("CFBundleName")
    else
      return if `ideviceinstaller -u #{@udid} -l`.include?("#{@bundle_id},")
    end
    Log.error("No such apps with bundle_id: #{@bundle_id}")
  end

  def save_screenshot
    Log.info('Saving screenshot 📷')
    png_path = "#{ATTACHMENTS_FOLDER}/*.png"
    new_path = "#{ATTACHMENTS_FOLDER}/ios_#{TIMESTAMP}.png"
    `xcparse screenshots #{XCRESULTS_FOLDER} #{ATTACHMENTS_FOLDER}`
    screenshots = Dir[png_path].collect { |png| File.expand_path(png) }
    FileUtils.cp(screenshots[0], new_path)
    FileUtils.rm_rf(XCRESULTS_FOLDER)
  end

  def check_udid
    return unless @simulator.nil?
    Log.info('Checking device udid 👨‍💻')
    @simulator = `xcrun simctl list`.include?(@udid) unless @udid.nil?
    @udid = devices.first if @udid.nil? && devices.size == 1
    Log.error("Provide device udid [-u]") if @udid.nil?
    unless @simulator || devices.include?(@udid)
      Log.error("No such devices with udid: #{@udid}")
    end
  end
end
