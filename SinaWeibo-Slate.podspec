
Pod::Spec.new do |s|

  s.name         = "SinaWeibo-Slate"
  s.version      = "0.1.1"
  s.summary      = "Slate SinaWeibo Wrapper."


  s.description  = <<-DESC
		   Slate SinaWeibo Wrapper.   
	
                   DESC

  s.homepage     = "http://github.com/islate/SinaWeibo-Slate"
  s.license      = "Apache 2.0"
  s.author       = { "linyize" => "linyize@gmail.com" }
  s.platform     = :ios, "8.0"
  s.source       = { :git => "http://github.com/islate/SinaWeibo-Slate.git", :tag => "#{s.version}" }

  s.dependency 'SinaWeibo', '0.1.0'
  s.dependency 'DETweetComposer', '0.1.0'

  s.source_files  = 'WeiboWrapper.*'

end
