# coding: utf-8

module Lex
  class Lexer
    # Rules DSL used internally by {Lexer}
    #
    # @api private
    class RuleDSL
      attr_reader :lex_tokens,
                  :state_info,
                  :state_re,
                  :state_names,
                  :state_ignore,
                  :state_error,
                  :state_lexemes

      # @api private
      def initialize
        @state_info    = { initial: :inclusive }
        @state_ignore  = { initial: '' }  # Ignored characters for each state
        @state_error   = {} # Error conditions for each state
        @state_re      = Hash.new { |hash, name| hash[name] = {}} # Regexes for each state
        @state_names   = {} # Symbol names for each state
        @state_lexemes = Hash.new { |hash, name| hash[name] = State.new(name) }
        @lex_tokens    = []  # List of valid tokens
      end

      # Add tokens to lexer
      #
      # @api public
      def tokens(*value)
        @lex_tokens = value
      end

      # Add states to lexer
      #
      # @api public
      def states(value)
        @state_info.merge!(value)
      end

      # Specify lexing rule
      #
      # @param [Symbol] token_name
      #   the name of the token
      #
      # @param [Regex] pattern
      #   the regex pattern
      #
      # @param [Array] state_names
      #   the states that the rule applies in
      #   if left blank, then the rule applies in all inclusive states
      #
      # @api public
      def rule(token_name, pattern, state_names = [], &action)
        if state_names.empty?
          @state_info.each do |state_name, state_type|
            state_names.push(state_name) if state_type == :inclusive && !state_names.include?(state_name)
          end
        end
        if token_name =~ /^[[:upper:]]*$/ && !@lex_tokens.include?(token_name)
          complain("Rule defined for an unspecified token #{token_name}")
        end
        state_names.each do |state_name|
          state = @state_lexemes[state_name]
          state << Lexeme.new(token_name, pattern, &action)
        end
        state_names.each do |state_name|
          if @state_re[state_name].key?(token_name)
            complain("Rule for token '#{token_name}' and state '#{state_name}' redefined.")
          end
          @state_re[state_name][token_name] = pattern
        end
      end

      # Define ignore condition for a state
      #
      # @param [Symbol] states
      #   the optional state names
      #
      # @param [String] value
      #   the characters to ignore
      #
      # @api public
      def ignore(states, value = (not_set = true))
        if not_set
          value = states
          state_names = [:initial]
        else
          state_names = states.to_s.split('_').map(&:to_sym)
        end
        if !value.is_a?(String)
          logger.error("Ignore rule '#{value}' has to be defined with a string")
        end
        state_names.each do |state_name|
          @state_ignore[state_name] = value
        end
        @state_info.each do |state_name, state_type|
          if state_name != :initial && state_type == :inclusive
            if !@state_ignore.key?(state_name)
              @state_ignore[state_name] = @state_ignore[:initial]
            end
          end
        end
      end

      # Define error condition for a state
      #
      # @api public
      def error(states = :initial, &action)
        state_names = states.to_s.split('_').map(&:to_sym)
        state_names.each do |state_name|
          @state_error[state_name] = action
        end
        @state_info.each do |state_name, state_type|
          if state_name != :initial && state_type == :inclusive
            if !@state_error.key?(state_name)
              @state_error[state_name] = @state_error[:initial]
            end
          end
        end
      end

      private

      # @api private
      def complain(*args)
        raise LexerError, *args
      end
    end # RuleDSL
  end # Lexer
end # Lex
