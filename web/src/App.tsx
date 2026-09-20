import React, { useState, useEffect } from 'react';
import { 
  Calculator, 
  Settings as SettingsIcon, 
  History as HistoryIcon, 
  Plus, 
  Trash2, 
  ChevronRight, 
  Leaf, 
  DollarSign, 
  Percent,
  Ruler,
  Save,
  Check
} from 'lucide-react';
import clsx from 'clsx';
import { twMerge } from 'tailwind-merge';

// --- Utils ---
function cn(...inputs: (string | undefined | null | false)[]) {
  return twMerge(clsx(inputs));
}

// Hook for localStorage
function useLocalStorage<T>(key: string, initialValue: T): [T, (value: T | ((val: T) => T)) => void] {
  const [storedValue, setStoredValue] = useState<T>(() => {
    if (typeof window === 'undefined') {
      return initialValue;
    }
    try {
      const item = window.localStorage.getItem(key);
      return item ? JSON.parse(item) : initialValue;
    } catch (error) {
      console.log(error);
      return initialValue;
    }
  });

  const setValue = (value: T | ((val: T) => T)) => {
    try {
      const valueToStore = value instanceof Function ? value(storedValue) : value;
      setStoredValue(valueToStore);
      if (typeof window !== 'undefined') {
        window.localStorage.setItem(key, JSON.stringify(valueToStore));
      }
    } catch (error) {
      console.log(error);
    }
  };

  return [storedValue, setValue];
}

// --- Models ---
interface TreeItem {
  id: string;
  circumference: number;
  height: number;
  notes: string;
}

interface Quote {
  id: string;
  date: string;
  subtotal: number;
  taxAmount: number;
  discountAmount: number;
  total: number;
  trees: TreeItem[];
  customerName?: string;
}

// --- Components ---

const Button = ({ className, children, ...props }: React.ButtonHTMLAttributes<HTMLButtonElement>) => (
  <button 
    className={cn("px-4 py-2 rounded-lg font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-primary/50", className)}
    {...props}
  >
    {children}
  </button>
);

const Input = ({ label, icon: Icon, ...props }: React.InputHTMLAttributes<HTMLInputElement> & { label: string, icon?: React.ElementType }) => (
  <div className="space-y-1">
    <label className="text-sm font-medium text-gray-700">{label}</label>
    <div className="relative">
      {Icon && (
        <div className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400">
          <Icon size={18} />
        </div>
      )}
      <input 
        className={cn(
          "w-full rounded-lg border-gray-300 border bg-white px-3 py-2 text-sm placeholder:text-gray-400 focus:border-primary focus:outline-none focus:ring-1 focus:ring-primary",
          Icon && "pl-10"
        )}
        {...props}
      />
    </div>
  </div>
);

const Card = ({ children, className }: { children: React.ReactNode, className?: string }) => (
  <div className={cn("bg-white rounded-xl shadow-sm border border-gray-100 p-4", className)}>
    {children}
  </div>
);

// --- Views ---

const OnboardingView = ({ onComplete }: { onComplete: () => void }) => (
  <div className="min-h-screen flex flex-col items-center justify-center p-6 bg-gradient-to-br from-green-50 to-green-100 text-center">
    <div className="w-24 h-24 bg-primary rounded-3xl flex items-center justify-center mb-8 shadow-green-200 shadow-xl">
      <Leaf className="text-white w-12 h-12" />
    </div>
    <h1 className="text-3xl font-bold text-gray-900 mb-2">Tree Cost Calculator</h1>
    <p className="text-gray-600 mb-8 max-w-xs">Easily calculate tree removal estimates, manage quotes, and track your history.</p>
    <Button onClick={onComplete} className="w-full max-w-xs bg-primary text-white hover:bg-secondary shadow-lg shadow-green-200">
      Get Started
    </Button>
  </div>
);

const CalculatorView = () => {
  // Settings
  const [startingFee] = useLocalStorage('startingFee', 0);
  const [pricePerCubicFoot] = useLocalStorage('pricePerCubicFoot', 10);
  const [taxRate] = useLocalStorage('taxRate', 0);
  const [showTax] = useLocalStorage('showTaxCalculator', false);
  const [showDiscount] = useLocalStorage('showDiscount', false);
  const [defaultDiscount] = useLocalStorage('defaultDiscountPercent', 0);
  
  // History
  const [history, setHistory] = useLocalStorage<Quote[]>('quoteHistory', []);

  // Form State
  const [circumference, setCircumference] = useState('');
  const [height, setHeight] = useState('');
  const [trees, setTrees] = useState<TreeItem[]>([]);
  const [discountPercent, setDiscountPercent] = useState(defaultDiscount.toString());
  
  // Computed
  const currentVolume = (Number(circumference) > 0 && Number(height) > 0) 
    ? (Number(circumference) * Number(circumference) * Number(height)) / 12.56 
    : 0;

  const totalVolume = trees.reduce((acc, tree) => {
    return acc + (tree.circumference * tree.circumference * tree.height) / 12.56;
  }, 0) + currentVolume;

  const subtotal = (totalVolume * pricePerCubicFoot) + startingFee;
  const discountAmount = showDiscount ? subtotal * (Number(discountPercent) / 100) : 0;
  const taxableAmount = subtotal - discountAmount;
  const taxAmount = showTax ? taxableAmount * (taxRate / 100) : 0;
  const total = taxableAmount + taxAmount;

  const addTree = () => {
    if (!currentVolume) return;
    setTrees([...trees, {
      id: crypto.randomUUID(),
      circumference: Number(circumference),
      height: Number(height),
      notes: ''
    }]);
    setCircumference('');
    setHeight('');
  };

  const removeTree = (id: string) => {
    setTrees(trees.filter(t => t.id !== id));
  };

  const saveQuote = () => {
    const quote: Quote = {
      id: crypto.randomUUID(),
      date: new Date().toISOString(),
      subtotal,
      taxAmount,
      discountAmount,
      total,
      trees: trees.length > 0 ? trees : (currentVolume > 0 ? [{
         id: crypto.randomUUID(),
         circumference: Number(circumference),
         height: Number(height),
         notes: ''
      }] : [])
    }
    
    if (quote.trees.length === 0) return;

    setHistory([quote, ...history]);
    setTrees([]);
    setCircumference('');
    setHeight('');
    alert('Quote saved to history!');
  };

  return (
    <div className="space-y-6 pb-24">
      <Card className="bg-primary text-white border-none shadow-green-200 shadow-xl">
        <div className="text-center py-4">
          <p className="text-green-100 text-sm font-medium mb-1">Estimated Total</p>
          <h2 className="text-5xl font-bold">${total.toFixed(2)}</h2>
          <div className="mt-4 flex justify-between text-sm text-green-100 px-4">
            <span>Vol: {totalVolume.toFixed(2)} ft³</span>
            <span>Trees: {trees.length + (currentVolume > 0 ? 1 : 0)}</span>
          </div>
        </div>
      </Card>

      <div className="grid grid-cols-2 gap-4">
        <Input 
          label="Circumference (ft)" 
          type="number" 
          inputMode="decimal"
          icon={Ruler}
          value={circumference}
          onChange={(e) => setCircumference(e.target.value)}
          placeholder="0.0"
        />
        <Input 
          label="Height (ft)" 
          type="number" 
          inputMode="decimal"
          icon={Ruler}
          value={height}
          onChange={(e) => setHeight(e.target.value)}
          placeholder="0.0"
        />
      </div>

      {currentVolume > 0 && (
        <Card className="bg-green-50 border-green-100 flex items-center justify-between">
          <div>
             <p className="font-semibold text-gray-900">Current Tree</p>
             <p className="text-sm text-gray-500">{currentVolume.toFixed(2)} ft³ · ${((currentVolume * pricePerCubicFoot)).toFixed(2)}</p>
          </div>
          <Button onClick={addTree} className="bg-white text-primary hover:bg-green-50 border border-green-200">
            <Plus size={20} />
          </Button>
        </Card>
      )}

      {trees.length > 0 && (
        <div className="space-y-3">
          <h3 className="font-medium text-gray-900 px-1">Added Trees ({trees.length})</h3>
          {trees.map((tree, i) => (
            <Card key={tree.id} className="flex items-center justify-between py-3">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center text-primary font-bold text-sm">
                  {i + 1}
                </div>
                <div>
                  <p className="text-sm font-medium">
                    {tree.circumference}' × {tree.height}'
                  </p>
                  <p className="text-xs text-gray-500">
                    {((tree.circumference * tree.circumference * tree.height) / 12.56).toFixed(2)} ft³
                  </p>
                </div>
              </div>
              <button 
                onClick={() => removeTree(tree.id)}
                className="text-gray-400 hover:text-red-500 p-2"
              >
                <Trash2 size={18} />
              </button>
            </Card>
          ))}
        </div>
      )}

      <Card className="space-y-3">
        <h3 className="font-medium text-gray-900 border-b border-gray-100 pb-2">Price Breakdown</h3>
        <div className="space-y-2 text-sm">
          <div className="flex justify-between">
             <span className="text-gray-500">Starting Fee</span>
             <span>${startingFee.toFixed(2)}</span>
          </div>
          <div className="flex justify-between">
             <span className="text-gray-500">Subtotal ({totalVolume.toFixed(2)} ft³)</span>
             <span>${(totalVolume * pricePerCubicFoot).toFixed(2)}</span>
          </div>
          {showDiscount && (
             <div className="flex justify-between items-center text-orange-600">
                <span className="flex items-center gap-2">
                  Discount 
                  <div className="w-16">
                    <input 
                      type="number"
                      className="w-full text-right border-b border-orange-200 focus:outline-none text-xs py-0.5"
                      value={discountPercent} 
                      onChange={(e) => setDiscountPercent(e.target.value)} 
                    />
                  </div>
                  %
                </span>
                <span>-${discountAmount.toFixed(2)}</span>
             </div>
          )}
          {showTax && (
             <div className="flex justify-between text-gray-600">
                <span>Tax ({taxRate}%)</span>
                <span>${taxAmount.toFixed(2)}</span>
             </div>
          )}
          <div className="flex justify-between font-bold text-lg pt-2 border-t border-gray-100">
             <span>Total</span>
             <span>${total.toFixed(2)}</span>
          </div>
        </div>
      </Card>
      
      <Button onClick={saveQuote} className="w-full bg-primary text-white py-3 shadow-lg hover:bg-secondary flex items-center justify-center gap-2">
        <Save size={18} /> Save Quote
      </Button>
    </div>
  );
};

const SettingsView = () => {
  const [startingFee, setStartingFee] = useLocalStorage('startingFee', 0);
  const [pricePerCubicFoot, setPricePerCubicFoot] = useLocalStorage('pricePerCubicFoot', 10);
  const [taxRate, setTaxRate] = useLocalStorage('taxRate', 0);
  const [showTax, setShowTax] = useLocalStorage('showTaxCalculator', false);
  const [showDiscount, setShowDiscount] = useLocalStorage('showDiscount', false);
  const [defaultDiscount, setDefaultDiscount] = useLocalStorage('defaultDiscountPercent', 0);
  const [hasCompletedOnboarding, setHasCompletedOnboarding] = useLocalStorage('hasCompletedOnboarding', true);

  const resetOnboarding = () => {
     setHasCompletedOnboarding(false);
     window.location.reload();
  }

  return (
    <div className="space-y-6 pb-24">
       <Card>
         <h3 className="font-medium text-gray-900 mb-4 flex items-center gap-2"><DollarSign size={18}/> Pricing</h3>
         <div className="space-y-4">
           <Input 
             label="Starting Fee ($)" 
             type="number" 
             value={startingFee} 
             onChange={(e) => setStartingFee(Number(e.target.value))} 
           />
           <Input 
             label="Price Per Cubic Foot ($)" 
             type="number" 
             value={pricePerCubicFoot} 
             onChange={(e) => setPricePerCubicFoot(Number(e.target.value))} 
           />
         </div>
       </Card>

       <Card>
         <h3 className="font-medium text-gray-900 mb-4 flex items-center gap-2"><Percent size={18}/> Tax & Discount</h3>
         <div className="space-y-4">
           
           <div className="flex items-center justify-between">
             <label className="text-sm font-medium text-gray-700">Calculate Tax</label>
             <button 
               onClick={() => setShowTax(!showTax)}
               className={cn("w-12 h-6 rounded-full transition-colors relative", showTax ? "bg-primary" : "bg-gray-200")}
             >
                <div className={cn("w-5 h-5 bg-white rounded-full absolute top-0.5 transition-all shadow-sm", showTax ? "left-6.5" : "left-0.5")} />
             </button>
           </div>
           
           {showTax && (
              <Input 
               label="Tax Rate (%)" 
               type="number" 
               value={taxRate} 
               onChange={(e) => setTaxRate(Number(e.target.value))} 
             />
           )}

           <div className="flex items-center justify-between pt-2 border-t border-gray-100">
             <label className="text-sm font-medium text-gray-700">Enable Discounts</label>
             <button 
               onClick={() => setShowDiscount(!showDiscount)}
               className={cn("w-12 h-6 rounded-full transition-colors relative", showDiscount ? "bg-primary" : "bg-gray-200")}
             >
                <div className={cn("w-5 h-5 bg-white rounded-full absolute top-0.5 transition-all shadow-sm", showDiscount ? "left-6.5" : "left-0.5")} />
             </button>
           </div>

           {showDiscount && (
              <Input 
               label="Default Discount (%)" 
               type="number" 
               value={defaultDiscount} 
               onChange={(e) => setDefaultDiscount(Number(e.target.value))} 
             />
           )}
         </div>
       </Card>

       <div className="pt-8">
          <Button onClick={resetOnboarding} className="w-full bg-gray-100 text-gray-600 hover:bg-gray-200">
             Show Onboarding Again
          </Button>
          <p className="text-center text-xs text-gray-400 mt-4">Version 1.0.0 (Web) by Ryan Hamilton</p>
       </div>
    </div>
  )
}

const HistoryView = () => {
  const [history, setHistory] = useLocalStorage<Quote[]>('quoteHistory', []);

  const deleteQuote = (id: string) => {
    if(confirm('Delete this quote?')) {
      setHistory(history.filter(h => h.id !== id));
    }
  }

  return (
    <div className="space-y-4 pb-24">
      {history.length === 0 ? (
        <div className="text-center py-12 text-gray-400">
           <HistoryIcon size={48} className="mx-auto mb-4 opacity-50" />
           <p>No saved quotes yet</p>
        </div>
      ) : (
        history.map(quote => (
           <Card key={quote.id} className="group relative overflow-hidden">
              <div className="flex justify-between items-start mb-2">
                 <div>
                    <p className="font-bold text-lg text-gray-900">${quote.total.toFixed(2)}</p>
                    <p className="text-xs text-gray-500">{new Date(quote.date).toLocaleDateString()} {new Date(quote.date).toLocaleTimeString()}</p>
                 </div>
                 <button onClick={() => deleteQuote(quote.id)} className="text-gray-300 hover:text-red-500 transition-colors">
                    <Trash2 size={18} />
                 </button>
              </div>
              <div className="text-sm text-gray-600">
                 {quote.trees.length} tree{quote.trees.length !== 1 ? 's' : ''} calculated
              </div>
           </Card>
        ))
      )}
    </div>
  )
}

function App() {
  const [hasCompletedOnboarding, setHasCompletedOnboarding] = useLocalStorage('hasCompletedOnboarding', false);
  const [activeTab, setActiveTab] = useState<'calculator' | 'history' | 'settings'>('calculator');

  if (!hasCompletedOnboarding) {
    return <OnboardingView onComplete={() => setHasCompletedOnboarding(true)} />;
  }

  return (
    <div className="min-h-screen bg-gray-50 font-sans text-gray-900">
      <header className="bg-white border-b border-gray-200 px-4 py-3 sticky top-0 z-30 flex items-center justify-between shadow-sm">
        <h1 className="text-lg font-bold flex items-center gap-2 text-primary">
          <Leaf className="fill-primary" size={20} />
          Tree Cost Calc
        </h1>
        {activeTab !== 'calculator' && (
           <span className="text-xs font-semibold uppercase tracking-wider text-gray-400">{activeTab}</span>
        )}
      </header>

      <main className="p-4 max-w-md mx-auto">
        {activeTab === 'calculator' && <CalculatorView />}
        {activeTab === 'history' && <HistoryView />}
        {activeTab === 'settings' && <SettingsView />}
      </main>

      <nav className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 px-6 py-2 pb-safe z-40">
        <div className="flex justify-around items-center max-w-md mx-auto">
          <button 
            onClick={() => setActiveTab('calculator')}
            className={cn("flex flex-col items-center gap-1 p-2 rounded-lg transition-colors", activeTab === 'calculator' ? "text-primary" : "text-gray-400 hover:text-gray-600")}
          >
            <Calculator size={24} strokeWidth={activeTab === 'calculator' ? 2.5 : 2} />
            <span className="text-[10px] font-medium">Calculate</span>
          </button>
          
          <button 
            onClick={() => setActiveTab('history')}
            className={cn("flex flex-col items-center gap-1 p-2 rounded-lg transition-colors", activeTab === 'history' ? "text-primary" : "text-gray-400 hover:text-gray-600")}
          >
            <HistoryIcon size={24} strokeWidth={activeTab === 'history' ? 2.5 : 2} />
            <span className="text-[10px] font-medium">History</span>
          </button>

          <button 
            onClick={() => setActiveTab('settings')}
            className={cn("flex flex-col items-center gap-1 p-2 rounded-lg transition-colors", activeTab === 'settings' ? "text-primary" : "text-gray-400 hover:text-gray-600")}
          >
            <SettingsIcon size={24} strokeWidth={activeTab === 'settings' ? 2.5 : 2} />
            <span className="text-[10px] font-medium">Settings</span>
          </button>
        </div>
      </nav>
    </div>
  );
}

export default App
