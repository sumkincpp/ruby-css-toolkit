$:.unshift File.dirname(__FILE__)
require 'css_properties'
require 'css_stylesheet'
require 'css_rule_set'
require 'css_declaration'

module CssTidy

	class Parser
		# these are used to poke values in for testing instance methods
		attr_accessor :css, :index, :sheet

		# parser current context
		NONE				= 0
		IN_SELECTOR = 1
		IN_PROPERTY = 2
		IN_VALUE		= 3
		IN_STRING		= 4
		IN_COMMENT	= 5
		IN_AT_BLOCK	= 6

		# setup the class vars used by Tidy
		def initialize

			# temporary array to hold data during development
			@stylesheet = CssToolkit::StyleSheet.new

			# the raw, unprocessed css
			@raw_css = ''

			# the string that is being processed
			@css = ''

			# the current position in the string
			@index = 0

			# the current parser context. i.e where we are in the CSS
			@context = [NONE, IN_SELECTOR]

			# the current line number
			@line_number = 1
		end

		def parse(css)
			css_length = css.length
			@css = css.clone

			# vars used in processing of sheets
			current_at_block = ''
			invalid_at = false
			current_selector = ''
			current_property = ''
			current_ruleset = CssToolkit::RuleSet.new

			current_value = ''
			sub_value = ''
			sub_value_array = []

			current_string = ''
			string_char = ''
			str_in_str = false

			current_comment = ''

			while @index < css_length

				if is_newline?
					@line_number += 1
				end

				case @context.last
				when IN_AT_BLOCK
					if is_token
						if is_comment
							@context << IN_COMMENT
							@index += 1 # move past '*'
						elsif is_char '{'
							@context << IN_SELECTOR
						elsif is_char ','
							current_at_block = current_at_block.strip + ','
						elsif is_char '\\'
							current_at_block << convert_unicode
						end # of is_comment
					else # not token
	          lastpos = current_at_block.length - 1
						if( (is_char_ctype?(:space, current_at_block[last_position,1]) || is_char_token?(current_at_block[last_position,1]) && current_at_block[last_position,1] == ',') && is_ctype?(:space) )
	          	current_at_block << current_char
	          end
					end

				when IN_SELECTOR
          if is_token?
						if is_comment? && current_selector.strip.empty?
							@context << IN_COMMENT
							@index += 1
	       		elsif is_current_char?('@') && current_selector.empty?
	            # # Check for at-rule
	            # $this->invalid_at = true;
	            # foreach($at_rules as $name => $type)
	            # {
	            #     if(!strcasecmp(substr($string,$i+1,strlen($name)),$name))
	            #     {
	            #         ($type == 'at') ? $this->at = '@'.$name : $this->selector = '@'.$name;
	            #         $this->status = $type;
	            #         $i += strlen($name);
	            #         $this->invalid_at = false;
	            #     }
	            # }
	            #
	            # if($this->invalid_at)
	            # {
	            #     $this->selector = '@';
	            #     $invalid_at_name = '';
	            #     for($j = $i+1; $j < $size; ++$j)
	            #     {
	            #         if(!ctype_alpha($string{$j}))
	            #         {
	            #             break;
	            #         }
	            #         $invalid_at_name .= $string{$j};
	            #     }
	            #     $this->log('Invalid @-rule: '.$invalid_at_name.' (removed)','Warning');
	            # }
	          elsif is_current_char?('"') || is_current_char?("'")
							@context << IN_STRING
							current_string = current_char
							string_char = current_char
	          elsif invalid_at && is_current_char?(';')
							invalid_at = false
							@context << IN_SELECTOR
	          elsif is_current_char?('{')
							@context << IN_PROPERTY
	          elsif is_current_char?('}')
							current_at_block = ''
							current_selector = ''
							# save the last set
							@stylesheet << current_ruleset
							# start a new one
							current_ruleset = CssToolkit::RuleSet.new 
	          elsif is_current_char?(',')
							current_selector = current_selector.strip + ','
	          elsif is_current_char?('\\')
							current_selector << convert_unicode
	          #remove unnecessary universal selector,  FS#147
						#elseif ! (is_current_char?('*') && @in_array($string{$i+1}, array('.', '#', '[', ':'))))
						else
							current_selector << current_char
						end
          else # not is_token
						last_position = current_selector.length - 1
						if( lastpos == -1 || ! ( (is_char_ctype?(:space, current_selector[last_position,1]) || is_char_token?(current_selector[last_position,1]) && current_selector[last_position,1] == ',') && is_ctype?(:space) ))
	          	current_selector << current_char
	          end
          end

				when IN_PROPERTY
					if is_token?
						if (is_current_char?(':') || is_current_char?('=')) && ! current_property.empty?
							@context << IN_VALUE
	          elsif is_comment? && current_property.empty?
							@context << IN_COMMENT
							@index += 1 # move past '*'
	          elsif is_current_char?('}')
							@context << IN_SELECTOR
							invalid_at = false
							current_selector = ''
							current_property = ''
							@stylesheet << current_ruleset
							current_ruleset = CssToolkit::RuleSet.new
	          elsif is_current_char?(';')
							current_property = ''
	          elsif is_current_char?('\\')
							current_property << convert_unicode
	          end
          elsif ! is_ctype?(:space)
						current_property << current_char
          end

				when IN_VALUE
          property_next = is_newline? && property_is_next? || @index == css_length-1
          if is_token? || property_next
	          if is_comment?
							@context << IN_COMMENT
							@index += 1
	          elsif is_current_char?('"') || is_current_char?("'") || is_current_char?('(')
							current_string = current_char
							string_char = is_current_char?('(') ? ')' : current_char
	            @context << IN_STRING
	          elsif is_current_char?(',')
	          	sub_value = sub_value.strip + ','
	          elsif is_current_char?('\\')
							sub_value << convert_unicode
	          elsif is_current_char?(';') || property_next
							if current_selector[0,1] == '@'
	            # if($this->selector{0} == '@' && isset($at_rules[substr($this->selector,1)]) && $at_rules[substr($this->selector,1)] == 'iv')
	            # {
	            #     $this->sub_value_arr[] = trim($this->sub_value);
	            #
	            #     $this->status = 'is';
	            #
	            #     switch($this->selector)
	            #     {
	            #         case '@charset': $this->charset = $this->sub_value_arr[0]; break;
	            #         case '@namespace': $this->namespace = implode(' ',$this->sub_value_arr); break;
	            #         case '@import': $this->import[] = implode(' ',$this->sub_value_arr); break;
	            #     }
	            #
	            #     $this->sub_value_arr = array();
	            #     $this->sub_value = '';
	            #     $this->selector = '';
	            #     $this->sel_separate = array();
	            # }
	            else
	            	@context << IN_PROPERTY
            	end
	          elsif ! is_current_char?('}')
	            sub_value << current_char
	          end

	          if (is_current_char?('}') || is_current_char?(';') || property_next) && ! current_selector.empty?
	            if current_at_block.empty?
		          	current_at_block = '41';
	            end

	            if ! sub_value.empty?
	              sub_value_array << sub_value.strip
	              sub_value = ''
	            end

	            current_value = sub_value_array.join(' ')

	            valid = is_property_valid?(current_property)
	            if (! invalid_at || valid)
                #$this->css_add_property($this->at,$this->selector,$this->property,$this->value);
								current_ruleset.add_rule({:selector => current_selector.strip, :declarations => "#{current_property}:#{current_value}" })
								#  = CssToolkit::RuleSet.new
								# ruleset = CssToolkit::RuleSet.new
								# @stylesheet << ruleset								# add_rule
								# 	@sheet << "#{current_at_block.strip} | #{current_selector.strip} | #{current_property.strip} | #{current_value.strip}"
	            end

	            current_property = ''
							sub_value_array = []
	            current_value = ''
	          end

	          if is_current_char?('}')
							@context << IN_SELECTOR
							invalid_at = false
							current_selector = ''
	          end
          elsif ! property_next
	          sub_value << current_char

	          if is_ctype?(:space)
							if ! sub_value.empty?
	              sub_value_array << sub_value.strip
	              sub_value = ''
	            end
	          end
          end

				when IN_STRING
					if string_char === ')' && (is_current_char?('"') || is_current_char?("'")) && ! str_in_str && ! is_escaped?
						str_in_str = true
					elsif string_char === ')' && (is_current_char?('"') || is_current_char?("'")) && str_in_str && ! is_escaped?
						str_in_str = false
					end
					temp_add = current_char	# // ...and no not-escaped backslash at the previous position

					if is_newline? && !is_current_char?('\\') && ! is_escaped?(-1)
						temp_add = "\\A "
           	#$this->log('Fixed incorrect newline in string','Warning');
					end

	        if !(string_char === ')' && is_css_whitespace?(current_char) && !str_in_str)
						current_string << temp_add
	        end

          if is_current_char?(string_char) && !is_escaped? && !str_in_str
						@context.pop

						if is_css_whitespace?(current_string) && current_property != 'content'
							if (!quoted_string)
								if (string_char === '"' || string_char === '\'')
									# Temporarily disable this optimization to avoid problems with @charset rule, quote properties, and some attribute selectors...
									# Attribute selectors fixed, added quotes to @chartset, no problems with properties detected. Enabled
									#current_string = current_string.slice($this->cur_string, 1, -1);
								elsif (current_string > 3) && (current_string[1,1] === '"' || current_string[1,1] === '\'')
									#current_string = current_string + substr($this->cur_string, 2, -2) . substr($this->cur_string, -1);
								end
							else
								quoted_string = false
							end
						end

						if @context[-1] === IN_VALUE # from in value?
               sub_value << current_string
            elsif @context[-1] === IN_SELECTOR
	            current_selector << current_string;
            end
					end

				when IN_COMMENT
					if is_comment_end?
						@context.pop # go back to previous context
						@index += 1 # skip the '/'
						current_comment = ''
          else
						current_comment << current_char
          end

				end
				@index += 1
			end

			@stylesheet
		end

		def current_char
			@css[@index,1]
		end

		 # Checks if the next word in a string from after current index is a CSS property
		def property_is_next?
			pos = @css.index(':', @index+1)

			if ! pos
				return false
			end

			# get the length until just before the ':'
			size_of_property = pos - @index - 1

			# extract the name of the property
			property_to_find = (@css[@index+1,size_of_property]).strip.downcase

			if PROPERTIES.has_key?(property_to_find)
				#$this->log('Added semicolon to the end of declaration','Warning');
				return true
			else
				return false
			end
		end

		def is_property_valid?(property)
			PROPERTIES.has_key?(property)
		end

		def is_css_whitespace?(char)
			WHITESPACE.include?(char)
		end


		# These functions all test the character at the current index location

		def is_token?(offset=0)
			is_char_token?(@css[@index+offset,1])
		end

		def is_char_token?(char)
			TOKENS.include?(char)
		end

		# Checks if a character is escaped (and returns true if it is)
		def is_escaped?(offset=0)
			is_char_escaped?(@css[@index+offset-1,1])
		end

		def is_char_escaped?(char)
			# cannot backtrack before index '1' (would be -1, or the end of the string)
			if @index > 0
				if char === '\\'
					return true
				end
			end
			false
		end


		def is_comment?
			# cannot look beyond the end of the string
			if @index < @css.length
				if @css[@index, 2] == '/*'
					return true
				end
			end
			false
		end

		def is_comment_end?
			# cannot look beyond the end of the string
			if @index < @css.length
				if @css[@index, 2] == '*/'
					return true
				end
			end
			false
		end

		def is_newline?
			@css[@index,1] =~ /\n|\r/
		end

		def is_ctype?(ctype, offset=0)
			if @index < @css.length
				is_char_ctype?(ctype, @css[@index+offset,1])
			end
		end

		def is_char_ctype?(ctype, char)
			case ctype
			when :space
				char =~ / |\t|\f|\v|\n|\r/
			when :xdigit # hexidecimal
				char =~ /[0-9a-f]/i
			when :alpha
				char =~ /[A-Za-z]/
			end
		end

		# any sort of character - use for readability
		def is_current_char?(char,offset=0)
			case char.class.to_s
			when 'String'
				@css[@index+offset,1] == char
			when 'Array'
				char.include?(@css[@index+offset,1])
			end
		end

		def convert_unicode
			@index += 1
			add = '';
			replaced = false;
			length = @css.length
			# collect the unicode numbers
			while (@index < length && (is_ctype?(:xdigit)) || (is_ctype?(:space)) && add.length < 6)
				add << current_char
				if is_ctype?(:space)
					break;
				end
				@index += 1
			end
			code = add.to_i(10)
			if (code > 47 && code < 58) || (code > 64 && code < 91) || (code > 96 && code < 123)
				add = code.chr
				replaced = true
			else
				add = '\\' + add.strip
			end

			if is_ctype?(:xdigit, 1) && is_ctype?(:space) && ( !replaced || !is_ctype?(:space))
				@index -= 1;
			end

			if(add != '\\' || ! is_token?(1))
				return add;
			end

			if(add == '\\')
				puts('Removed unnecessary backslash','Information');
			end
			return ''
		end

		private

		# debugging help
		def context_name
			# parser current context
			case @context.last
			when NONE
				'None'
			when IN_SELECTOR
				'in selector'
			when IN_PROPERTY
				'in property'
			when IN_VALUE
				'in value'
			when IN_STRING
				'in string'
			when IN_COMMENT
				'in comment'
			when IN_AT_BLOCK
				'in at block'
			end
		end

	end
end