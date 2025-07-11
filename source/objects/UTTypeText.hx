package objects;

import flixel.system.FlxAssets;
import flixel.math.FlxRandom;
import openfl.media.Sound;

private var controls(get, never):Controls;
private function get_controls() return Controls.instance;

class UTTypeText extends FlxText {
	public var delay:Float = 0.05;
	public var eraseDelay:Float = 0.02;
	var trueDelay:Float = 0.05;
	public var showCursor:Bool = false;
	public var cursorCharacter:String = "|";
	public var cursorBlinkSpeed:Float = 0.5;
	public var prefix:String = "";
	public var autoErase:Bool = false;
	public var waitTime:Float = 1.0;
	public var paused:Bool = false;
	public var sounds:Array<FlxSound>;
	public var finishSounds = false;
	public var canSkip:Bool = true;
	public var completeCallback:Void->Void;
	public var eraseCallback:Void->Void;
    
	var _finalText:String = "";
	var _timer:Float = 0.0;
	var _waitTimer:Float = 0.0;
	var _length:Int = 0;
	var _typing:Bool = false;
	var _erasing:Bool = false;
	var _waiting:Bool = false;
	var _cursorTimer:Float = 0.0;
	var _typingVariation:Bool = false;
	var _typeVarPercent:Float = 0.5;
	static var helperString:String = "";
	var _sound:FlxSound;

    var _ignoreCharacters:Array<String> = ["`", "~", "!", "*", "(", ")", "-", "_", "=", "+", "{", "}", "[", "]", '"', "'", "\\", "|", ":", ";", ",", "<", ".", ">", "/", "?", "^", " "];
	var _punctuationChars:Array<String> = [".", ",", "!", "?", ":", ";"];

	public function new(X:Float, Y:Float, Width:Int, Text:String, Font:String, Size:Int = 8, Color:FlxColor = FlxColor.WHITE) {
		super(X, Y, Width);
		_finalText = Text;
        setFormat(Paths.font(Font), Size, Color, LEFT);
        antialiasing = false;
        scrollFactor.set();
	}

	public function start(?Delay:Float, ForceRestart:Bool = false, AutoErase:Bool = false, ?Callback:Void->Void):Void {
		if (Delay != null) delay = Delay;

		_typing = true;
		_erasing = false;
		paused = false;
		_waiting = false;

		if (ForceRestart) {
			text = "";
			_length = 0;
		}

		autoErase = AutoErase;

		if (Callback != null) completeCallback = Callback;

		insertBreakLines();

        if (sounds == null) sounds = [FlxG.sound.load(Paths.sound('dialogue/txt_none', 'overworld'), 0.8)];
	}

	override public function applyMarkup(input:String, rules:Array<FlxTextFormatMarkerPair>):FlxText {
		super.applyMarkup(input, rules);
		resetText(text);
		return this;
	}

	function insertBreakLines() {
		var saveText = text;

		var last = _finalText.length;
		var n0:Int = 0;
		var n1:Int = 0;

		while (true) {
			last = _finalText.substr(0, last).lastIndexOf(" ");

			if (last <= 0)
				break;

			text = prefix + _finalText;
			n0 = textField.numLines;

			var nextText = _finalText.substr(0, last) + "\n" + _finalText.substr(last + 1, _finalText.length);

			text = prefix + nextText;
			n1 = textField.numLines;

			if (n0 == n1) _finalText = nextText;
		}

		text = saveText;
	}

	public function erase(?Delay:Float, ForceRestart:Bool = false, ?Callback:Void->Void):Void {
		_erasing = true;
		_typing = false;
		paused = false;
		_waiting = false;

		if (Delay != null) eraseDelay = Delay;

		if (ForceRestart) {
			_length = _finalText.length;
			text = _finalText;
		}

		eraseCallback = Callback;
	}

	public function resetText(Text:String):Void {
		text = "";
		_finalText = Text;
		_typing = false;
		_erasing = false;
		paused = false;
		_waiting = false;
		_length = 0;
		trueDelay = delay;
	}

	public function setTypingVariation(Amount:Float = 0.5, On:Bool = true):Void {
		_typingVariation = On;
		_typeVarPercent = FlxMath.bound(Amount, 0, 1);
	}

	function onComplete():Void {
		_timer = 0;
		_typing = false;

		if (sounds != null) {
			for (sound in sounds) sound.stop();
		}

		if (completeCallback != null) completeCallback();

		if (autoErase && waitTime <= 0) _erasing = true;
		else if (autoErase) {
			_waitTimer = waitTime;
			_waiting = true;
		}
	}

	function onErased():Void {
		_timer = 0;
		_erasing = false;

		if (eraseCallback != null) eraseCallback();
	}

	override public function update(elapsed:Float):Void {
		#if FLX_KEYBOARD
		if (canSkip && controls.DIA_SKIP) skip();
		#end

		if (_waiting && !paused) {
			_waitTimer -= elapsed;

			if (_waitTimer <= 0) {
				_waiting = false;
				_erasing = true;
			}
		}

		if (!_waiting && !paused && ((_length < _finalText.length && _typing) || (_length > 0 && _erasing)))
			_timer += elapsed;

		if (_typing || _erasing) {
			if (_typing && _timer >= trueDelay) {
				_length += Std.int(_timer / trueDelay);
				if (_length > _finalText.length)
					_length = _finalText.length;
			}

			if (_erasing && _timer >= eraseDelay) {
				_length -= Std.int(_timer / eraseDelay);
				if (_length < 0)
					_length = 0;
			}

			if ((_typing && _timer >= trueDelay) || (_erasing && _timer >= eraseDelay)) {
				if (_punctuationChars.contains(_finalText.charAt(_length - 2)) && !_punctuationChars.contains(_finalText.charAt(_length - 1)) && !_punctuationChars.contains(_finalText.charAt(_length)) && _length > 1)
					trueDelay = 0.3;
				else 
					trueDelay = _erasing ? eraseDelay : delay;
				
				if (_typingVariation)
					_timer = FlxG.random.float(-trueDelay * _typeVarPercent / 2, trueDelay * _typeVarPercent / 2);
				else 
					_timer %= trueDelay;

                if (!_ignoreCharacters.contains(_finalText.charAt(_length - 1)) && sounds != null) {
                    if (!finishSounds) for (sound in sounds) sound.stop();
                    FlxG.random.getObject(sounds).play(!finishSounds);
                }
			}
		}

		helperString = prefix + _finalText.substr(0, _length);

		if (showCursor) {
			_cursorTimer += elapsed;

			var isBreakLine = (prefix + _finalText).charAt(helperString.length) == "\n";

			if (_cursorTimer > cursorBlinkSpeed / 2 && !isBreakLine) helperString += cursorCharacter.charAt(0);

			if (_cursorTimer > cursorBlinkSpeed) _cursorTimer = 0;
		}

		if (helperString != text) {
			text = helperString;

			if (_length >= _finalText.length && _typing && !_waiting && !_erasing) onComplete();

			if (_length == 0 && _erasing && !_typing && !_waiting) onErased();
		}

		super.update(elapsed);
	}

	public function skip():Void {
		if (_erasing || _waiting) {
			_length = 0;
			_waiting = false;
		} else if (_typing) _length = _finalText.length;
	}
}